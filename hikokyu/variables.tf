variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name" {
  type    = string
  default = "pokemon-grader-api"
}

variable "lambda_zip" {
  type    = string
  default = "api.zip"
}

variable "origin_secret" {
  type      = string
  sensitive = true
}

variable "ebay_client_id" {
  type = string
}

variable "ebay_client_secret" {
  type      = string
  sensitive = true
}

variable "psa_api_token" {
  type      = string
  sensitive = true
}

variable "ebay_redirect_uri" {
  type        = string
  description = "eBay OAuth2 redirect URI (RU name) for user authorization code grant"
}

variable "admin_secret" {
  type      = string
  sensitive = true
}

variable "crawler_zip" {
  type    = string
  default = "crawler.zip"
}

variable "cf_key_pair_id" {
  type        = string
  default     = ""
  description = "CloudFront public key ID for URL signing"
}

variable "cf_private_key_secret" {
  type        = string
  default     = ""
  description = "Secrets Manager ARN for CloudFront private key PEM"
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications"
}

variable "enable_canary" {
  type    = bool
  default = true
}
