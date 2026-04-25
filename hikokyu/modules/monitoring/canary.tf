# Health canary — gated by var.enable_canary

resource "aws_lambda_function" "canary" {
  count            = var.enable_canary ? 1 : 0
  function_name    = "hikokyu-health-canary"
  runtime          = "provided.al2"
  handler          = "bootstrap"
  filename         = "${path.module}/../../canary.zip"
  source_code_hash = var.enable_canary ? filebase64sha256("${path.module}/../../canary.zip") : ""
  role             = var.lambda_role_arn
  architectures    = ["arm64"]
  timeout          = 30

  environment {
    variables = {
      API_URL       = var.api_url
      ADMIN_SECRET  = var.admin_secret
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "canary" {
  count             = var.enable_canary ? 1 : 0
  name              = "/aws/lambda/hikokyu-health-canary"
  retention_in_days = 7
}

resource "aws_cloudwatch_event_rule" "canary_schedule" {
  count               = var.enable_canary ? 1 : 0
  name                = "hikokyu-health-canary"
  description         = "Health check canary every 15 minutes"
  schedule_expression = "rate(15 minutes)"
}

resource "aws_cloudwatch_event_target" "canary_target" {
  count = var.enable_canary ? 1 : 0
  rule  = aws_cloudwatch_event_rule.canary_schedule[0].name
  arn   = aws_lambda_function.canary[0].arn
}

resource "aws_lambda_permission" "canary_eventbridge" {
  count         = var.enable_canary ? 1 : 0
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.canary[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.canary_schedule[0].arn
}

resource "aws_cloudwatch_metric_alarm" "canary_errors" {
  count               = var.enable_canary ? 1 : 0
  alarm_name          = "hikokyu-canary-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 900
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.canary[0].function_name
  }
}

# Grant the shared Lambda role permission to publish to the alerts topic.
# The canary reuses the existing IAM role (var.lambda_role_arn) which lives
# in the iam module, so we attach an inline policy here from the monitoring
# module where the SNS topic is defined.
resource "aws_iam_role_policy" "canary_sns_publish" {
  count = var.enable_canary ? 1 : 0
  name  = "hikokyu-canary-sns-publish"
  role  = element(split("/", var.lambda_role_arn), length(split("/", var.lambda_role_arn)) - 1)

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sns:Publish"]
      Resource = aws_sns_topic.alerts.arn
    }]
  })
}
