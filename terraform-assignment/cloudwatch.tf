# ============================================================
# CloudWatch Alarms: Ensures the pipeline is healthy and scalable.
# All alarms notify the Security Alerts SNS Topic.
# ============================================================

# ------------------------------------------------------------
# 1. Lambda Trigger Alarms (Ingestion Start)
# ------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_trigger_errors" {
  # Naming Convention: {prefix}-trigger-errors
  alarm_name          = "${local.resource_prefix}-trigger-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  # Human Description: Focus on the impact (validation/start failure)
  alarm_description   = "Alert when file trigger Lambda errors (Indicates input validation or SFN start failures)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.trigger_step_function.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_trigger_throttles" {
  # Naming Convention: {prefix}-trigger-throttles
  alarm_name          = "${local.resource_prefix}-trigger-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  # Human Description: Focus on capacity limits
  alarm_description   = "Alert when the file trigger is being throttled (S3 event volume exceeds Lambda's capacity)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.trigger_step_function.function_name
  }

  tags = local.common_tags
}

# ------------------------------------------------------------
# 2. Lambda Writer Alarms (DynamoDB Persistence)
# ------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "lambda_writer_errors" {
  # Naming Convention: {prefix}-writer-errors
  alarm_name          = "${local.resource_prefix}-writer-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  # Human Description: Focus on potential DDB or permission issues
  alarm_description   = "Alert when the DDB writer Lambda fails (Requires checking DDB permissions or Step Function input)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.write_to_dynamodb.function_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_writer_throttles" {
  # Naming Convention: {prefix}-writer-throttles
  alarm_name          = "${local.resource_prefix}-writer-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  # Human Description: Focus on concurrency need
  alarm_description   = "Alert when the DDB writer Lambda is throttled (May require concurrency limit increase)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.write_to_dynamodb.function_name
  }

  tags = local.common_tags
}

# ------------------------------------------------------------
# 3. Step Functions Alarms (Workflow Reliability)
# ------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "step_function_failures" {
  # Naming Convention: {prefix}-sfn-failures
  alarm_name          = "${local.resource_prefix}-sfn-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 2
  # Human Description: Focus on workflow failures
  alarm_description   = "Alert when file processing workflows fail (Critical, check SFN definition or underlying Lambda failures)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.file_processor.arn
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "step_function_timeouts" {
  # Naming Convention: {prefix}-sfn-timeouts
  alarm_name          = "${local.resource_prefix}-sfn-timeouts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ExecutionsTimedOut"
  namespace           = "AWS/States"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  # Human Description: Focus on excessive processing time
  alarm_description   = "Alert when file processing executions time out (Review SFN state or Lambda execution duration)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.file_processor.arn
  }

  tags = local.common_tags
}

# ------------------------------------------------------------
# 4. DynamoDB Alarms
# ------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  # Naming Convention: {prefix}-ddb-throttles
  alarm_name          = "${local.resource_prefix}-ddb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  # Metric Name: UserErrors often indicates throttling in DDB
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  # Human Description: Focus on the capacity impact
  alarm_description   = "Alert when the DDB table encounters user errors (Indicates read/write capacity limits are being hit)."
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    # FIX: Corrected resource name from 'files' to 'files_metadata' 
    # to match the declaration in dynamodb.tf.
    TableName = aws_dynamodb_table.files_metadata.name
  }

  tags = local.common_tags
}