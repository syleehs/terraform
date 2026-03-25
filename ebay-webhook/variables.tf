variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "name" {
  description = "Project name"
  type        = string
}

variable "lambda_zip" {
  description = "Path to Lambda zip file"
  type        = string
}

variable "origin_secret" {
  description = "Secret header between CloudFront and Lambda"
  type        = string
  sensitive   = true
}

variable "ebay_client_id" {
  description = "eBay application Client ID (production keyset)"
  type        = string
}

variable "ebay_client_secret" {
  description = "eBay application Client Secret (production keyset)"
  type        = string
  sensitive   = true
}

variable "verification_token" {
  description = "eBay verification token"
  type        = string
}

variable "endpoint" {
  description = "Webhook endpoint"
  type        = string
}

variable "discord_webhook_url" {
  description = "Discord webhook URL for notifications"
  type        = string
  sensitive   = true
}