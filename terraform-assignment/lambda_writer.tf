# ============================================================
# Lambda Function: Writer (DynamoDB Persistence)
# This function is executed by Step Functions to save file metadata.
# ============================================================
resource "aws_lambda_function" "write_to_dynamodb" {
    filename         = "${path.module}/lambda_writer.zip"
    # Naming: Clear purpose (writer DDB) and professional prefix
    function_name    = "${local.resource_prefix}-writer-ddb-lambda"
    role             = aws_iam_role.lambda_writer.arn
    handler          = "index.handler"
    runtime          = "python3.11"
    
    # Structural Fix: Ensure clear, single-line HCL arguments
    timeout          = 30 
    source_code_hash = filebase64sha256("${path.module}/lambda_writer.zip") 

    environment {
        variables = {
            # Pass the DDB table name so the Lambda knows where to write the data
            TABLE_NAME = aws_dynamodb_table.files_metadata.name
        }
    }

    tags = merge(
        local.common_tags,
        {
            # Tag Name reflects the professional function name
            Name = "${local.resource_prefix}-writer-ddb-lambda"
        }
    )
}

# =======================================================
# CRITICAL FIX: Allow SFN to Invoke the Lambda Writer
# Live AWS requires this resource-based policy grant to 
# resolve the Step Function's FAILED status (Access Denied).
# =======================================================
resource "aws_lambda_permission" "allow_sfn_to_invoke_writer" {
    statement_id  = "AllowSFNInvokeWriterLambda"
    action        = "lambda:InvokeFunction"
    
    # Targets the Lambda function defined above
    function_name = aws_lambda_function.write_to_dynamodb.function_name
    
    # The principal is the AWS Step Functions service
    principal     = "states.amazonaws.com" 
    
    # The source ARN restricts permission to this specific state machine
    source_arn    = aws_sfn_state_machine.file_processor.arn 
}