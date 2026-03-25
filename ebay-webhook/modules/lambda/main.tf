resource "aws_lambda_function" "this" {
  function_name = var.name
  runtime       = "provided.al2"
  handler       = "bootstrap"

  filename         = var.filename
  source_code_hash = filebase64sha256(var.filename)
  role             = var.role_arn
  architectures    = ["arm64"]

  environment {
    variables = {
      ORIGIN_SECRET        = var.origin_secret
      EBAY_CLIENT_ID       = var.ebay_client_id
      EBAY_CLIENT_SECRET   = var.ebay_client_secret
      VERIFICATION_TOKEN   = var.verification_token
      ENDPOINT             = var.endpoint
      DISCORD_WEBHOOK_URL  = var.discord_webhook_url
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
