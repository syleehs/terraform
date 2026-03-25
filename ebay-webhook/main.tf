provider "aws" {
  region = var.aws_region
}

module "iam" {
  source = "./modules/iam"
  name   = var.name
}

module "lambda" {
  source = "./modules/lambda"

  name              = var.name
  filename          = var.lambda_zip
  role_arn          = module.iam.role_arn
  origin_secret     = var.origin_secret
  ebay_client_id     = var.ebay_client_id
  ebay_client_secret = var.ebay_client_secret

  # REQUIRED
  verification_token  = var.verification_token
  endpoint            = var.endpoint
  discord_webhook_url = var.discord_webhook_url
}

module "lambda_url" {
  source        = "./modules/lambda_url"
  function_name = module.lambda.function_name
}

module "cloudfront" {
  source        = "./modules/cloudfront"
  lambda_url    = module.lambda_url.lambda_url
  origin_secret = var.origin_secret
}