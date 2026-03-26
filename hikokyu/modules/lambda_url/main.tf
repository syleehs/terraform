resource "aws_lambda_function_url" "this" {
  function_name      = var.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "public_url" {
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = var.function_name
  principal              = "*"
  statement_id           = "AllowPublicAccess"
  function_url_auth_type = "NONE"
}

output "lambda_url" {
  value = aws_lambda_function_url.this.function_url
}

variable "function_name" {}
