output "cloudfront_url" {
  value = module.cloudfront.domain_name
}

output "lambda_url" {
  value = module.lambda_url.lambda_url
}