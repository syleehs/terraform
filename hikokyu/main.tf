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
  allowed_origin     = "https://d13tqu8zrmovi6.cloudfront.net,*"
  dynamodb_table     = module.dynamodb.table_name
  psa_api_token      = var.psa_api_token
  admin_secret       = var.admin_secret
  image_bucket       = "gradeguess-site"
  image_cdn_url      = "https://d13tqu8zrmovi6.cloudfront.net"
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

module "lambda_crawler" {
  source         = "./modules/lambda_crawler"
  name           = "${var.name}-crawler"
  filename       = var.crawler_zip
  role_arn       = module.iam.role_arn
  dynamodb_table = module.dynamodb.table_name
  psa_api_token      = var.psa_api_token
  image_bucket       = "gradeguess-site"
  image_cdn_url      = "https://d13tqu8zrmovi6.cloudfront.net"
  ebay_client_id     = var.ebay_client_id
  ebay_client_secret = var.ebay_client_secret
}

resource "aws_cloudwatch_event_rule" "crawler_schedule" {
  name                = "${var.name}-crawler-schedule"
  description         = "Nightly crawler at 04:05 UTC (after PSA quota reset ~04:00 UTC)"
  schedule_expression = "cron(5 4 * * ? *)"
}

resource "aws_cloudwatch_event_target" "crawler_target" {
  rule = aws_cloudwatch_event_rule.crawler_schedule.name
  arn  = module.lambda_crawler.function_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler_schedule.arn
}

