variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name" {
  type    = string
  default = "gradeguess-site"
}

variable "cf_public_key_pem" {
  type        = string
  description = "CloudFront signing public key PEM content"
}
