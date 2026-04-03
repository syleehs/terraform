resource "aws_dynamodb_table" "prices" {
  name         = var.name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "card"
  range_key    = "fetched_at"

  attribute {
    name = "card"
    type = "S"
  }

  attribute {
    name = "fetched_at"
    type = "N"
  }

  server_side_encryption {
    enabled = true
  }
}

output "table_name" {
  value = aws_dynamodb_table.prices.name
}

output "table_arn" {
  value = aws_dynamodb_table.prices.arn
}

variable "name" {}
