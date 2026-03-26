resource "aws_dynamodb_table" "prices" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "card"

  attribute {
    name = "card"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

output "table_name" {
  value = aws_dynamodb_table.prices.name
}

output "table_arn" {
  value = aws_dynamodb_table.prices.arn
}

variable "name" {}
