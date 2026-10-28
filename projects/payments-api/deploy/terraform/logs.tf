# Application and audit logs: encrypted with the service key and kept for a year.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/${var.name}/api"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.service.arn
}

resource "aws_cloudwatch_log_group" "risk_monitor" {
  name              = "/${var.name}/risk-monitor"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.service.arn
}

# Count risk alerts from the consumer's structured logs so they can be alarmed on.
resource "aws_cloudwatch_log_metric_filter" "risk_alerts" {
  name           = "${var.name}-risk-alerts"
  log_group_name = aws_cloudwatch_log_group.risk_monitor.name
  pattern        = "{ $.msg = \"risk alert\" }"

  metric_transformation {
    name      = "RiskAlerts"
    namespace = "PaymentsApi"
    value     = "1"
    unit      = "Count"
  }
}
