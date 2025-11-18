variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name for resource tagging (e.g., File Upload System)"
  type        = string
  default     = "file-upload-system"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# MODIFIED: S3 buckets must be globally unique.
# We will construct a unique name in s3.tf using this.
variable "s3_bucket_base_name" {
  description = "Base name of the S3 bucket for file uploads"
  type        = string
  default     = "file-uploads-bucket" 
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "Files"
}

variable "security_alert_email" {
  description = "Email address for security alerts. Must be a real email you can access."
  type        = string
  default     = "alerts@test.com"
}

locals {
  # The fixed, professional prefix used for naming all core AWS resources.
  # This ensures clarity and operational hygiene.
  resource_prefix = "swisssom-terraform"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
