package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
)

type healthResponse struct {
	Status string `json:"status"`
}

func handler(ctx context.Context) error {
	apiURL := os.Getenv("API_URL")
	secret := os.Getenv("ADMIN_SECRET")
	topicARN := os.Getenv("SNS_TOPIC_ARN")

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL+"/health", nil)
	if err != nil {
		return publishAlert(ctx, topicARN, fmt.Sprintf("Failed to build health request: %v", err))
	}
	req.Header.Set("Authorization", "Bearer "+secret)

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return publishAlert(ctx, topicARN, fmt.Sprintf("Health check failed: %v", err))
	}
	defer resp.Body.Close()

	b, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		return publishAlert(ctx, topicARN, fmt.Sprintf("Health endpoint returned %d: %s", resp.StatusCode, string(b)))
	}

	var health healthResponse
	if err := json.Unmarshal(b, &health); err != nil {
		return publishAlert(ctx, topicARN, fmt.Sprintf("Failed to parse health response: %v", err))
	}

	if health.Status == "error" {
		return publishAlert(ctx, topicARN, fmt.Sprintf("Hikokyu health: ERROR\n%s", string(b)))
	}

	return nil
}

func publishAlert(ctx context.Context, topicARN, message string) error {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return fmt.Errorf("load AWS config: %w", err)
	}
	snsClient := sns.NewFromConfig(cfg)
	subject := "Hikokyu Health Alert"
	_, err = snsClient.Publish(ctx, &sns.PublishInput{
		TopicArn: &topicARN,
		Subject:  &subject,
		Message:  &message,
	})
	return err
}

func main() {
	lambda.Start(handler)
}
