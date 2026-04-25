# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "hikokyu-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Metric Filters
resource "aws_cloudwatch_log_metric_filter" "ebay_auth_failures" {
  name           = "EbayAuthFailures"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" && $.source = \"ebay\" && $.action = \"get_token\" }"

  metric_transformation {
    name      = "EbayAuthFailures"
    namespace = "Hikokyu"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "ebay_search_failures" {
  name           = "EbaySearchFailures"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" && $.source = \"ebay\" }"

  metric_transformation {
    name      = "EbaySearchFailures"
    namespace = "Hikokyu"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "psa_quota_warning" {
  name           = "PSAQuotaWarning"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"WARN\" && $.source = \"psa\" }"

  metric_transformation {
    name      = "PSAQuotaWarning"
    namespace = "Hikokyu"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "health_degraded" {
  name           = "HealthDegraded"
  log_group_name = var.log_group_name
  pattern        = "{ $.level = \"ERROR\" && $.action = \"health_check\" }"

  metric_transformation {
    name      = "HealthDegraded"
    namespace = "Hikokyu"
    value     = "1"
  }
}

# Alarms
resource "aws_cloudwatch_metric_alarm" "ebay_auth" {
  alarm_name          = "hikokyu-ebay-auth-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EbayAuthFailures"
  namespace           = "Hikokyu"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "ebay_search" {
  alarm_name          = "hikokyu-ebay-search-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EbaySearchFailures"
  namespace           = "Hikokyu"
  period              = 900
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "psa_quota" {
  alarm_name          = "hikokyu-psa-quota-warning"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "PSAQuotaWarning"
  namespace           = "Hikokyu"
  period              = 3600
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "health_degraded" {
  alarm_name          = "hikokyu-health-degraded"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthDegraded"
  namespace           = "Hikokyu"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
}
