output "api_url" {
  value = "https://${module.cloudfront.domain_name}"
}

output "site_url" {
  value = module.frontend.url
}

output "site_bucket" {
  value = module.frontend.bucket_name
}
