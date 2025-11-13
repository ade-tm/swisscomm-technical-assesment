# ============================================================
# 1. Lambda Trigger Role (S3 -> Step Functions)
# Goal: Only permission to start the SFN and write logs.
# ============================================================

resource "aws_iam_role" "lambda_trigger" {
  # Naming: Clear purpose and prefix
  name = "${local.resource_prefix}-trigger-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_trigger" {
  # Naming: Policy name reflects the role's function
  name = "${local.resource_prefix}-trigger-sfn-policy"
  role = aws_iam_role.lambda_trigger.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${aws_lambda_function.trigger_step_function.function_name}:*"
      },
      {
        Sid      = "StartStepFunction"
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = aws_sfn_state_machine.file_processor.arn
      }
    ]
  })
}

# ============================================================
# 2. Lambda Writer Role (Write to DynamoDB)
# Goal: Only permission to write DDB metadata and use the DDB KMS key.
# ============================================================

resource "aws_iam_role" "lambda_writer" {
  # Naming: Clear purpose and prefix
  name = "${local.resource_prefix}-writer-ddb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "lambda_writer" {
  # Naming: Policy name reflects the role's function
  name = "${local.resource_prefix}-writer-ddb-policy"
  role = aws_iam_role.lambda_writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${aws_lambda_function.write_to_dynamodb.function_name}:*"
      },
      {
        Sid      = "DynamoDBWrite"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        # CORRECT REFERENCE: This is the correct resource name defined in your dynamodb.tf
        Resource = aws_dynamodb_table.files_metadata.arn 
      },
      {
        Sid    = "KMSDecryptForDynamoDB"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.dynamodb.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "dynamodb.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ============================================================
# 3. Security Monitor Role (Read S3/DynamoDB configs, Publish SNS)
# Goal: Permissions to audit and notify.
# ============================================================

resource "aws_iam_role" "security_monitor" {
  # Naming: Clear purpose and prefix
  name = "${local.resource_prefix}-security-auditor-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "security_monitor" {
  # Naming: Policy name reflects the role's function
  name = "${local.resource_prefix}-security-auditor-policy"
  role = aws_iam_role.security_monitor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${aws_lambda_function.security_monitor.function_name}:*"
      },
      {
        Sid    = "S3ReadEncryptionConfig"
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBReadConfig"
        Effect = "Allow"
        Action = [
          "dynamodb:ListTables",
          "dynamodb:DescribeTable"
        ]
        Resource = "*"
      },
      {
        Sid      = "PublishToSecurityTopic"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Sid    = "KMSForSNS"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = aws_kms_key.sns.arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "sns.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# ============================================================
# 4. Step Functions Role
# Goal: Permissions to execute the writer Lambda.
# ============================================================

resource "aws_iam_role" "step_functions" {
  # Naming: Clear purpose and prefix
  name = "${local.resource_prefix}-sfn-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "step_functions" {
  # Naming: Policy name reflects the role's function
  name = "${local.resource_prefix}-sfn-execution-policy"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeSpecificLambda"
        Effect   = "Allow"
        Action   = "lambda:InvokeFunction"
        Resource = aws_lambda_function.write_to_dynamodb.arn
      },
      {
        Sid      = "PublishToSNS"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      },
      {
        Sid    = "CloudWatchLogsForStepFunctions"
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups"
        ]
        Resource = "*"
      }
    ]
  })
}