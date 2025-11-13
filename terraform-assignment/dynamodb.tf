# ============================================================
# DynamoDB Table: Stores File Metadata
# ============================================================

resource "aws_dynamodb_table" "files_metadata" {
  # Naming: Uses the professional prefix and clearly identifies the table's contents.
  # New Name: swisssom-terraform-ingest-file-metadata-ddb
  name             = "${local.resource_prefix}-file-metadata-ddb"
  billing_mode     = "PAY_PER_REQUEST" # Choose on-demand to handle variable upload traffic

  # --- Primary Key ---
  hash_key         = "Filename"
  range_key        = "UploadTimestamp"

  attribute {
    name = "Filename"
    type = "S" # String
  }

  attribute {
    name = "UploadTimestamp"
    type = "S" # String (ISO-8601 format for time-series data)
  }


  # This ensures data is secured using our project's custom managed key.
  server_side_encryption {
    enabled = true
    # Reference the KMS Key created in kms.tf
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  # Standard operational tags
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-MetadataTable"
    }
  )
}