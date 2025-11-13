# ============================================================
# KMS Keys: Centralized Management for Encryption-at-Rest
# We use separate keys for S3, DynamoDB, and SNS for clear audit
# trails and adherence to the principle of least access.
# ============================================================

# --- KMS Key for S3 Data Bucket ---
resource "aws_kms_key" "s3" {
  description             = "KMS key dedicated to encrypting all objects in the S3 file ingestion bucket."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      # New Name: swisssom-terraform-ingest-s3-key
      Name    = "${local.resource_prefix}-s3-key"
      Purpose = "S3 bucket encryption"
    }
  )
}

resource "aws_kms_alias" "s3" {
  # New Name: alias/swisssom-terraform-ingest-s3
  name            = "alias/${local.resource_prefix}-s3"
  target_key_id   = aws_kms_key.s3.key_id
}

# --- KMS Key for DynamoDB Metadata Table ---
resource "aws_kms_key" "dynamodb" {
  description             = "KMS key dedicated to encrypting the file metadata stored in the DynamoDB table."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      # New Name: swisssom-terraform-ingest-dynamodb-key
      Name    = "${local.resource_prefix}-dynamodb-key"
      Purpose = "DynamoDB table encryption"
    }
  )
}

resource "aws_kms_alias" "dynamodb" {
  # New Name: alias/swisssom-terraform-ingest-dynamodb
  name            = "alias/${local.resource_prefix}-dynamodb"
  target_key_id   = aws_kms_key.dynamodb.key_id
}

# --- KMS Key for SNS Security Alerts ---
resource "aws_kms_key" "sns" {
  description             = "KMS key dedicated to encrypting messages sent to the SNS security alert topic."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      # New Name: swisssom-terraform-ingest-sns-key
      Name    = "${local.resource_prefix}-sns-key"
      Purpose = "SNS topic encryption"
    }
  )
}

resource "aws_kms_alias" "sns" {
  # New Name: alias/swisssom-terraform-ingest-sns
  name            = "alias/${local.resource_prefix}-sns"
  target_key_id   = aws_kms_key.sns.key_id
}