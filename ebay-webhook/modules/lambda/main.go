package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

type config struct {
	Endpoint          string
	VerificationToken string
	ClientID          string
	ClientSecret      string
}

var (
	cfg      config
	keyCache sync.Map
)

// challengeResponse computes SHA256(challengeCode + verificationToken + endpoint)
func challengeResponse(challengeCode string) string {
	h := sha256.New()
	h.Write([]byte(challengeCode))
	h.Write([]byte(cfg.VerificationToken))
	h.Write([]byte(cfg.Endpoint))
	return hex.EncodeToString(h.Sum(nil))
}

type ebaySignature struct {
	Kid       string `json:"kid"`
	Signature string `json:"signature"`
}

func getPublicKey(kid string) (string, error) {
	if v, ok := keyCache.Load(kid); ok {
		return v.(string), nil
	}

	creds := base64.URLEncoding.EncodeToString([]byte(cfg.ClientID + ":" + cfg.ClientSecret))
	data := url.Values{}
	data.Set("grant_type", "client_credentials")
	data.Set("scope", "https://api.ebay.com/oauth/api_scope")

	req, _ := http.NewRequest("POST", "https://api.ebay.com/identity/v1/oauth2/token", strings.NewReader(data.Encode()))
	req.Header.Set("Authorization", "Basic "+creds)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var tokenResp map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&tokenResp)
	token, ok := tokenResp["access_token"].(string)
	if !ok {
		return "", fmt.Errorf("no access_token in response")
	}

	req2, _ := http.NewRequest("GET", "https://api.ebay.com/commerce/notification/v1/public_key/"+kid, nil)
	req2.Header.Set("Authorization", "bearer "+token)

	resp2, err := http.DefaultClient.Do(req2)
	if err != nil {
		return "", err
	}
	defer resp2.Body.Close()

	var keyResp struct {
		Key string `json:"key"`
	}
	json.NewDecoder(resp2.Body).Decode(&keyResp)

	keyCache.Store(kid, keyResp.Key)
	return keyResp.Key, nil
}

func validateSignature(body string, signatureHeader string) bool {
	raw, err := base64.StdEncoding.DecodeString(signatureHeader)
	if err != nil {
		return false
	}

	var sig ebaySignature
	if err := json.Unmarshal(raw, &sig); err != nil {
		return false
	}

	rawKey, err := getPublicKey(sig.Kid)
	if err != nil {
		return false
	}

	rawKey = strings.Replace(rawKey, "-----BEGIN PUBLIC KEY-----", "-----BEGIN PUBLIC KEY-----\n", 1)
	rawKey = strings.Replace(rawKey, "-----END PUBLIC KEY-----", "\n-----END PUBLIC KEY-----", 1)

	block, _ := pem.Decode([]byte(rawKey))
	if block == nil {
		return false
	}

	key, err := x509.ParsePKIXPublicKey(block.Bytes)
	if err != nil {
		return false
	}

	pubKey, ok := key.(*ecdsa.PublicKey)
	if !ok {
		return false
	}

	sigBytes, err := base64.StdEncoding.DecodeString(sig.Signature)
	if err != nil {
		return false
	}

	hash := sha1.Sum([]byte(body))
	return ecdsa.VerifyASN1(pubKey, hash[:], sigBytes)
}

func notifyDiscord(body string) {
	webhookURL := os.Getenv("DISCORD_WEBHOOK_URL")
	if webhookURL == "" {
		return
	}

	var notification struct {
		Metadata struct {
			Topic string `json:"topic"`
		} `json:"metadata"`
		Notification struct {
			NotificationID string `json:"notificationId"`
			EventDate      string `json:"eventDate"`
			Data           struct {
				Username string `json:"username"`
				UserID   string `json:"userId"`
			} `json:"data"`
		} `json:"notification"`
	}
	json.Unmarshal([]byte(body), &notification)

	content := fmt.Sprintf(
		"**eBay Alert: %s**\nUser: %s (`%s`)\nEvent: %s\nID: %s",
		notification.Metadata.Topic,
		notification.Notification.Data.Username,
		notification.Notification.Data.UserID,
		notification.Notification.EventDate,
		notification.Notification.NotificationID,
	)

	payload, _ := json.Marshal(map[string]string{"content": content})
	http.Post(webhookURL, "application/json", strings.NewReader(string(payload)))
}

func handler(ctx context.Context, req events.LambdaFunctionURLRequest) (events.LambdaFunctionURLResponse, error) {
	if req.Headers["x-origin-secret"] != os.Getenv("ORIGIN_SECRET") {
		return events.LambdaFunctionURLResponse{StatusCode: 403}, nil
	}

	switch strings.ToUpper(req.RequestContext.HTTP.Method) {
	case "GET":
		challengeCode := req.QueryStringParameters["challenge_code"]
		if challengeCode == "" {
			return events.LambdaFunctionURLResponse{StatusCode: 400}, nil
		}
		body, _ := json.Marshal(map[string]string{
			"challengeResponse": challengeResponse(challengeCode),
		})
		return events.LambdaFunctionURLResponse{
			StatusCode: 200,
			Body:       string(body),
			Headers:    map[string]string{"Content-Type": "application/json"},
		}, nil

	case "POST":
		sig := req.Headers["x-ebay-signature"]
		if sig == "" {
			return events.LambdaFunctionURLResponse{StatusCode: 400}, nil
		}
		if !validateSignature(req.Body, sig) {
			return events.LambdaFunctionURLResponse{StatusCode: 412}, nil
		}
		notifyDiscord(req.Body)
		return events.LambdaFunctionURLResponse{StatusCode: 204}, nil
	}

	return events.LambdaFunctionURLResponse{StatusCode: 405}, nil
}

func main() {
	cfg = config{
		Endpoint:          os.Getenv("ENDPOINT"),
		VerificationToken: os.Getenv("VERIFICATION_TOKEN"),
		ClientID:          os.Getenv("EBAY_CLIENT_ID"),
		ClientSecret:      os.Getenv("EBAY_CLIENT_SECRET"),
	}
	lambda.Start(handler)
}
