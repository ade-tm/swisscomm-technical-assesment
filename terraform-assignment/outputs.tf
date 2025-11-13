# ============================================================
# OUTPUTS: Key Resource Identifiers
# These outputs provide the necessary ARNs and names for use
# by administrators or other dependent systems (e.g., CI/CD).
# ============================================================

output "s3_bucket_name" {
  description = "The globally unique name of the S3 file ingestion bucket."
  value       = aws_s3_bucket.uploads.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 file ingestion bucket."
  value       = aws_s3_bucket.uploads.arn
}

output "dynamodb_table_name" {
  # Referencing the new resource name from dynamodb.tf
  description = "The human-readable name of the file metadata DynamoDB table."
  value       = aws_dynamodb_table.files_metadata.name 
}

output "step_function_arn" {
  description = "The ARN of the main file processing Step Function State Machine."
  value       = aws_sfn_state_machine.file_processor.arn
}

output "sns_topic_arn" {
  description = "The ARN of the security alerts SNS topic."
  value       = aws_sns_topic.security_alerts.arn
}

output "lambda_trigger_function_name" {
  # Referencing the new function name: swisssom-terraform-ingest-trigger-sfn-lambda
  description = "The human-readable name of the Lambda function that triggers the Step Function."
  value       = aws_lambda_function.trigger_step_function.function_name
}

output "lambda_writer_function_name" {
  # Referencing the new function name: swisssom-terraform-ingest-writer-ddb-lambda
  description = "The human-readable name of the Lambda function that writes data to DynamoDB."
  value       = aws_lambda_function.write_to_dynamodb.function_name
}

output "lambda_security_monitor_function_name" {
  # Referencing the new function name: swisssom-terraform-ingest-security-auditor-lambda
  description = "The human-readable name of the Lambda function for the security compliance audit."
  value       = aws_lambda_function.security_monitor.function_name
}

output "kms_key_s3_alias" {
  description = "The Alias name (alias/...) for the S3 encryption key."
  value       = aws_kms_alias.s3.name
}

output "kms_key_dynamodb_alias" {
  description = "The Alias name (alias/...) for the DynamoDB encryption key."
  value       = aws_kms_alias.dynamodb.name
}

output "kms_key_sns_alias" {
  description = "The Alias name (alias/...) for the SNS encryption key."
  value       = aws_kms_alias.sns.name
}