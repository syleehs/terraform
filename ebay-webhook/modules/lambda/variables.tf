variable "name" {
  type = string
}

variable "filename" {
  type = string
}

variable "role_arn" {
  type = string
}

variable "origin_secret" {
  type = string
}

variable "ebay_client_id" {
  type = string
}

variable "ebay_client_secret" {
  type      = string
  sensitive = true
}

# 👇 ADD THESE (your error)
variable "verification_token" {
  type = string
}

variable "endpoint" {
  type = string
}

variable "discord_webhook_url" {
  type      = string
  sensitive = true
}