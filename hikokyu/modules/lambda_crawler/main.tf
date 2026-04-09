resource "aws_lambda_function" "this" {
  function_name    = var.name
  runtime          = "provided.al2"
  handler          = "bootstrap"
  filename         = var.filename
  source_code_hash = filebase64sha256(var.filename)
  role             = var.role_arn
  architectures    = ["arm64"]
  timeout          = 300

  environment {
    variables = {
      DYNAMODB_TABLE     = var.dynamodb_table
      PSA_API_TOKEN      = var.psa_api_token
      IMAGE_BUCKET       = var.image_bucket
      IMAGE_CDN_URL      = var.image_cdn_url
      EBAY_CLIENT_ID     = var.ebay_client_id
      EBAY_CLIENT_SECRET = var.ebay_client_secret
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 7
}

output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "function_arn" {
  value = aws_lambda_function.this.arn
}

variable "name" {}
variable "filename" {}
variable "role_arn" {}
variable "dynamodb_table" {}
variable "psa_api_token"      { sensitive = true }
variable "image_bucket"       { default = "" }
variable "image_cdn_url"      { default = "" }
variable "ebay_client_id"     { default = "" }
variable "ebay_client_secret" {
  sensitive = true
  default   = ""
}
