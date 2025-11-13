# ============================================================
# Lambda Function: S3 Trigger (Ingress Gate)
# This function is the entry point, invoked directly by S3 events.
# Its only job is validation and starting the Step Function.
# ============================================================
resource "aws_lambda_function" "trigger_step_function" {
  filename         = "${path.module}/lambda_trigger.zip"
  # Naming: Clear purpose (trigger SFN) and professional prefix
  function_name    = "${local.resource_prefix}-trigger-sfn-lambda"
  role             = aws_iam_role.lambda_trigger.arn
  handler          = "index.handler"
  runtime          = "python3.11"
  timeout          = 30 # A short timeout is fine, as it only starts the SFN.
  source_code_hash = filebase64sha256("${path.module}/lambda_trigger.zip")

  environment {
    variables = {
      # Pass the ARN of the Step Function so the Lambda knows what to execute
      STATE_MACHINE_ARN = aws_sfn_state_machine.file_processor.arn
    }
  }

  tags = merge(
    local.common_tags,
    {
      # Tag Name reflects the professional function name
      Name = "${local.resource_prefix}-trigger-sfn-lambda"
    }
  )
}

# Lambda Permission - Allow S3 to Invoke
resource "aws_lambda_permission" "allow_s3" {
  # Standard statement ID for S3 permissions
  statement_id  = "AllowExecutionFromS3" 
  action        = "lambda:InvokeFunction"
  # This references the function name defined above
  function_name = aws_lambda_function.trigger_step_function.function_name
  principal     = "s3.amazonaws.com"
  # Least Privilege: Restrict permission to only our specific uploads bucket
  source_arn    = aws_s3_bucket.uploads.arn
}