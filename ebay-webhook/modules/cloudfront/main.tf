resource "aws_cloudfront_distribution" "this" {
  enabled = true

  origin {
    domain_name = trimsuffix(replace(var.lambda_url, "https://", ""), "/")
    origin_id   = "lambda-origin"

    custom_header {
      name  = "X-Origin-Secret"
      value = var.origin_secret
    }

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "lambda-origin"
    viewer_protocol_policy = "https-only"

    allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["X-Ebay-Signature"]

      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

output "domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

variable "lambda_url" {}
variable "origin_secret" {}