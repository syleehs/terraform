provider "aws" {
  region = var.aws_region
}

module "dynamodb" {
  source = "./modules/dynamodb"
  name   = "${var.name}-prices"
}

module "events" {
  source = "./modules/events"
}

module "iam" {
  source             = "./modules/iam"
  name               = var.name
  dynamodb_table_arn = module.dynamodb.table_arn
  cf_private_key_secret_arn = var.cf_private_key_secret
  events_firehose_arn       = module.events.stream_arn
}

module "lambda" {
  source             = "./modules/lambda"
  name               = var.name
  filename           = var.lambda_zip
  role_arn           = module.iam.role_arn
  ebay_client_id     = var.ebay_client_id
  ebay_client_secret = var.ebay_client_secret
  ebay_redirect_uri  = var.ebay_redirect_uri
  allowed_origin     = "https://slabble.app,https://www.slabble.app,https://d13tqu8zrmovi6.cloudfront.net,https://d28u6phz81nhwi.cloudfront.net,https://d3swclsoka9kct.cloudfront.net"
  dynamodb_table     = module.dynamodb.table_name
  psa_api_token      = var.psa_api_token
  admin_secret       = var.admin_secret
  image_bucket       = "gradeguess-site"
  image_cdn_url      = "https://d13tqu8zrmovi6.cloudfront.net"
  cf_key_pair_id        = var.cf_key_pair_id
  cf_private_key_secret = var.cf_private_key_secret
  firehose_stream_name  = module.events.stream_name
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
  redact_pct         = "20"
  ebay_client_id            = var.ebay_client_id
  ebay_client_secret        = var.ebay_client_secret
  api_cf_distribution_id    = module.cloudfront.distribution_id
}

resource "aws_cloudwatch_event_rule" "crawler_schedule" {
  name                = "${var.name}-crawler-schedule"
  description         = "Nightly crawler at 04:01 UTC (after PSA quota reset ~04:00 UTC)"
  schedule_expression = "cron(1 4 * * ? *)"
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

# Retry schedule: runs every 4 hours in case the 04:01 run was blocked by Cloudflare
resource "aws_cloudwatch_event_rule" "crawler_retry" {
  name                = "${var.name}-crawler-retry"
  description         = "Crawler retry every 4 hours in case PSA Cloudflare blocks the 04:01 run"
  schedule_expression = "rate(2 hours)"
}

resource "aws_cloudwatch_event_target" "crawler_retry_target" {
  rule = aws_cloudwatch_event_rule.crawler_retry.name
  arn  = module.lambda_crawler.function_arn
}

resource "aws_lambda_permission" "allow_eventbridge_retry" {
  statement_id  = "AllowEventBridgeRetry"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_crawler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler_retry.arn
}

module "monitoring" {
  source          = "./modules/monitoring"
  log_group_name  = "/aws/lambda/${var.name}"
  alert_email     = var.alert_email
  enable_canary   = var.enable_canary
  api_url         = "https://${module.cloudfront.domain_name}"
  admin_secret    = var.admin_secret
  lambda_role_arn = module.iam.role_arn
}

