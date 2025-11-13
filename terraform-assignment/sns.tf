# ============================================================
# SNS Topic: Security Alerts
# This topic is the communication hub for all non-compliant findings
# from the security auditor Lambda and execution failures from Step Functions.
# ============================================================
resource "aws_sns_topic" "security_alerts" {
  # Naming: Clear purpose and professional prefix
  name              = "${local.resource_prefix}-security-alerts"
  kms_master_key_id = aws_kms_key.sns.id # Encrypts messages with our dedicated KMS key

  tags = merge(
    local.common_tags,
    {
      # Tag Name reflects the professional function name
      Name = "${local.resource_prefix}-SecurityAlertsTopic"
    }
  )
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "security_team_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  # Endpoint is the email address specified in your variables
  endpoint  = var.security_alert_email
}

# CRUCIAL NOTE: When you deploy this, AWS will send a
# confirmation email to `var.security_alert_email`.
# You MUST click the link in that email to activate
# the subscription and receive alerts.