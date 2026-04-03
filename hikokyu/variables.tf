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

variable "tcgplayer_api_key" {
  type      = string
  sensitive = true
}
