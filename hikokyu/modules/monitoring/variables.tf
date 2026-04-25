variable "log_group_name" {
  type        = string
  description = "CloudWatch log group name for the API Lambda"
}

variable "alert_email" {
  type        = string
  description = "Email address for alarm notifications"
}

variable "enable_canary" {
  type    = bool
  default = true
}

variable "api_url" {
  type        = string
  default     = ""
  description = "API URL for health canary (required if enable_canary=true)"
}

variable "admin_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "Admin secret for health endpoint auth (required if enable_canary=true)"
}

variable "lambda_role_arn" {
  type        = string
  default     = ""
  description = "IAM role ARN for canary Lambda (required if enable_canary=true)"
}
