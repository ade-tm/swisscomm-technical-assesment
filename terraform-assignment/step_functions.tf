# ============================================================
# Step Functions: File Processing Workflow
# This State Machine defines the complete, reliable, and
# fault-tolerant workflow for processing a single file upload.
# ============================================================

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  # Naming: Use the vendor log path and clearly label the workflow
  name              = "/aws/vendedlogs/states/${local.resource_prefix}-file-processor"
  retention_in_days = 7

  tags = local.common_tags
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "file_processor" {
  # Naming: Clear purpose and professional prefix
  name     = "${local.resource_prefix}-file-processor-sfn"
  role_arn = aws_iam_role.step_functions.arn

  # NOTE: The dependency on aws_lambda_function.write_to_dynamodb is now implicit, 
  # as it's referenced in the definition and assumed by the ARN in role_arn.

  definition = jsonencode({
    Comment = "Process file upload and write metadata to DynamoDB with built-in retry and security alert handling."
    StartAt = "ValidateAndWrite"
    States = {
      # --- State 1: Primary Task (Validation and Persistence) ---
      ValidateAndWrite = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.write_to_dynamodb.arn
          Payload = {
            "bucket.$"    = "$.bucket"
            "key.$"       = "$.key"
            "timestamp.$" = "$.timestamp"
            "event_time.$" = "$.event_time"
          }
        }
        # Error Handling: Robust retry mechanism for transient service errors
        Retry = [
          {
            ErrorEquals     = ["States.TaskFailed", "States.Timeout"]
            IntervalSeconds = 2
            MaxAttempts     = 3
            BackoffRate     = 2.0
          }
        ]
        # Error Handling: Catches all errors (including validation failures in Lambda)
        Catch = [
          {
            ErrorEquals = ["States.ALL"]
            Next        = "HandleError"
            ResultPath  = "$.error"
          }
        ]
        Next = "Success"
      }
      
      # --- State 2: Error Notification (Runs on Catch) ---
      HandleError = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = aws_sns_topic.security_alerts.arn
          Subject  = "File Processing Error - Execution Failed"
          Message = {
            "ErrorMessage.$"  = "States.Format('Workflow failed to process file {}. Error: {}', $.key, $.error.Cause)"
            "InputData.$"     = "$.input"
            "ExecutionName.$" = "$$.Execution.Name"
            "StateMachine.$"  = "$$.StateMachine.Name"
          }
        }
        Next = "Fail"
      }
      
      # --- State 3: Success --
      Success = {
        Type = "Succeed"
      }
      
      # --- State 4: Hard Fail ---
      Fail = {
        Type  = "Fail"
        Error = "FileProcessingFailed"
        Cause = "File processing could not be completed after validation or task failure"
      }
    }
  })

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.step_functions.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  tags = local.common_tags
}