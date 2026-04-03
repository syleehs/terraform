provider "aws" {
  region = var.aws_region
}

module "dynamodb" {
  source = "./modules/dynamodb"
  name   = "${var.name}-prices"
}

module "iam" {
  source             = "./modules/iam"
  name               = var.name
  dynamodb_table_arn = module.dynamodb.table_arn
}

module "lambda" {
  source             = "./modules/lambda"
  name               = var.name
  filename           = var.lambda_zip
  role_arn           = module.iam.role_arn
  ebay_client_id     = var.ebay_client_id
  ebay_client_secret = var.ebay_client_secret
  ebay_redirect_uri  = var.ebay_redirect_uri
  allowed_origin     = "*"
  dynamodb_table     = module.dynamodb.table_name
  psa_api_token      = var.psa_api_token
  tcgplayer_api_key  = var.tcgplayer_api_key
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

module "frontend" {
  source = "./modules/frontend"
  name   = "${var.name}-site"
}

