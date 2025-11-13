# ============================================================
# Lambda Function: Security Auditor (Compliance Check)
# This function runs the security scan and publishes alerts.
# ============================================================
resource "aws_lambda_function" "security_monitor" {
  filename         = "${path.module}/lambda_security_monitor.zip"
  # Naming: Clear purpose and professional prefix
  function_name    = "${local.resource_prefix}-security-auditor-lambda"
  role             = aws_iam_role.security_monitor.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 300
  source_code_hash = filebase64sha256("${path.module}/lambda_security_monitor.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.security_alerts.arn
      # AWS_ENDPOINT_URL is correctly handled by localstack/provider.tf now
    }
  }

  tags = merge(
    local.common_tags,
    {
      # Tag Name reflects the professional function name
      Name = "${local.resource_prefix}-security-auditor-lambda"
    }
  )
}

# ============================================================
# EventBridge (CloudWatch Event Rule) - Schedule Daily Scan
# ============================================================
resource "aws_cloudwatch_event_rule" "security_scan" {
  # Naming: Clear purpose and professional prefix
  name                = "${local.resource_prefix}-security-scan-schedule"
  description         = "Trigger the compliance audit function daily."
  schedule_expression = "rate(24 hours)"

  tags = local.common_tags
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "security_scan" {
  rule      = aws_cloudwatch_event_rule.security_scan.name
  target_id = "SecurityMonitorLambda"
  arn       = aws_lambda_function.security_monitor.arn
}

# Lambda Permission - Allow EventBridge to Invoke Auditor
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_scan.arn
}