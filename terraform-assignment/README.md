# Serverless File Ingestion Pipeline

A production-ready, event-driven AWS architecture for secure file processing, built entirely with Terraform and designed with security-first principles.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Security Features](#security-features)
- [Troubleshooting](#troubleshooting)
- [Known Limitations](#known-limitations)
- [Assignment Requirements](#assignment-requirements)
- [Cleanup](#cleanup)
- [Additional Resources](#additional-resources)

---

## Overview

This project implements a secure, serverless pipeline that automatically processes files uploaded to S3. Every file upload triggers a workflow that validates the input, tracks metadata in DynamoDB, and maintains continuous security compliance through automated auditing.

### What This Solution Does

- Processes file uploads automatically when files land in S3
- Tracks metadata (filename and timestamp) in an encrypted DynamoDB table
- Enforces encryption across all services using AWS KMS
- Monitors security with a scheduled Lambda that scans for unencrypted resources
- Handles errors gracefully with retry logic and SNS notifications
- Validates all inputs to prevent common security vulnerabilities

### Why This Approach?

The architecture follows AWS best practices:

- **Least privilege access** - each service gets only the permissions it needs
- **Defense in depth** - multiple layers of security controls
- **Fail-safe defaults** - everything is encrypted unless explicitly configured otherwise
- **Audit everything** - comprehensive logging and monitoring throughout

---

## Architecture

### High-Level Flow

The pipeline operates as a fully event-driven workflow. When a user uploads a file to the S3 bucket, an S3 event notification immediately triggers the Trigger Lambda function. This function validates the file key for security issues like path traversal attacks, then initiates a Step Functions state machine to orchestrate the workflow. The state machine invokes the Writer Lambda function, which persists the file metadata (filename and upload timestamp) to an encrypted DynamoDB table. If any step fails, the state machine automatically retries up to three times with exponential backoff before sending a failure notification via SNS.

### Background Security Monitoring

A separate security monitoring process runs independently on a scheduled basis. CloudWatch Events triggers the Security Monitor Lambda function every 24 hours to perform compliance scans. This function examines all S3 buckets and DynamoDB tables in the account, checking whether encryption is properly enabled. If any unencrypted resources are detected, the monitor immediately publishes an alert to the SNS topic, notifying the security team of the compliance violation.

### Component Overview

| Component | Purpose | Key Features |
|-----------|---------|--------------|
| **S3 Bucket** | File storage | KMS encryption, versioning, 90-day lifecycle, public access blocked |
| **Trigger Lambda** | Event handler | Validates S3 keys, starts Step Functions, prevents path traversal |
| **Step Functions** | Workflow orchestrator | Retry logic (3 attempts), error handling, SNS notifications on failure |
| **Writer Lambda** | Data persistence | Writes to DynamoDB, duplicate detection, input validation |
| **DynamoDB** | Metadata storage | KMS encryption, point-in-time recovery, composite key (Filename + Timestamp) |
| **Security Monitor** | Compliance scanner | Daily scans, detects unencrypted resources, sends SNS alerts |
| **KMS Keys** | Encryption | Separate keys for S3, DynamoDB, and SNS with automatic rotation |

---

## Project Structure

```
terraform-assignment/
├── provider.tf                    # AWS/LocalStack provider configuration
├── variables.tf                   # Configurable parameters
├── outputs.tf                     # Resource outputs after deployment
│
├── kms.tf                        # KMS keys (S3, DynamoDB, SNS)
├── s3.tf                         # S3 bucket with security policies
├── dynamodb.tf                   # DynamoDB table configuration
├── sns.tf                        # SNS topic for alerts
├── iam.tf                        # IAM roles and policies
│
├── lambda_trigger.tf             # Trigger Lambda config
├── lambda_writer.tf              # Writer Lambda config
├── lambda_security_monitor.tf    # Security monitor config
├── step_functions.tf             # Step Functions state machine
├── cloudwatch.tf                 # CloudWatch alarms
│
├── lambda_trigger/
│   └── index.py                  # Trigger Lambda code
├── lambda_writer/
│   └── index.py                  # Writer Lambda code
├── lambda_security_monitor/
│   └── index.py                  # Security monitor code
│
├── tests/
│   ├── test_lambda_trigger.py    # Unit tests
│   ├── test_lambda_writer.py     # Unit tests
│   └── test_security_monitor.py  # Unit tests
│
├── scripts/
│   └── package_lambdas.sh        # Lambda packaging script
│
└── docker-compose.yml            # LocalStack configuration
```

---

## Prerequisites

Before getting started, make sure you have these installed:

- **Docker & Docker Compose** - for running LocalStack
- **Terraform** (v1.0+) - for infrastructure provisioning
- **AWS CLI** - for testing and validation
- **Python 3.11+** - for Lambda functions and unit tests
- **Bash** - for running helper scripts

---

## Getting Started

### 1. Start LocalStack

LocalStack provides a local AWS environment for testing without incurring costs.

```bash
# Start LocalStack in the background
docker-compose up -d

# Verify it's running
docker-compose logs -f localstack | grep "Ready"
```

You should see `Ready.` in the logs when LocalStack is fully initialized.

### 2. Configure AWS CLI

Set up your environment to point to LocalStack:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_REGION=eu-central-1
export ENDPOINT_URL=http://localhost:4566
```

**Note:** These are dummy credentials for LocalStack only. Never use these in production.

### 3. Package Lambda Functions

The Lambda functions need to be packaged into zip files before deployment:

```bash
# Make the script executable
chmod +x scripts/package_lambdas.sh

# Package all Lambda functions
./scripts/package_lambdas.sh
```

This creates three zip files:
- `lambda_trigger.zip`
- `lambda_writer.zip`
- `lambda_security_monitor.zip`

### 4. Deploy Infrastructure

Now deploy everything with Terraform:

```bash
# Initialize Terraform (first time only)
terraform init

# Preview what will be created
terraform plan

# Deploy the infrastructure
terraform apply
```

Type `yes` when prompted to confirm.

The deployment takes about 2-3 minutes and creates:
- 3 KMS keys
- 1 S3 bucket with security policies
- 1 DynamoDB table
- 3 Lambda functions
- 1 Step Functions state machine
- 1 SNS topic
- 5 CloudWatch alarms
- Multiple IAM roles and policies

### 5. Verify Deployment

Check that everything was created successfully:

```bash
# View Terraform outputs
terraform output

# List S3 buckets
aws --endpoint-url $ENDPOINT_URL s3 ls

# List DynamoDB tables
aws --endpoint-url $ENDPOINT_URL dynamodb list-tables

# List Lambda functions
aws --endpoint-url $ENDPOINT_URL lambda list-functions
```

---

## Testing

### Quick Test: Upload a File

The easiest way to test the entire pipeline:

```bash
# Create a test file
echo "Hello, this is a test file" > test.txt

# Upload to S3 (this triggers the entire workflow)
aws --endpoint-url $ENDPOINT_URL s3 cp test.txt \
  s3://$(terraform output -raw s3_bucket_name)/test.txt \
  --sse aws:kms

# Wait a few seconds, then check DynamoDB
aws --endpoint-url $ENDPOINT_URL dynamodb scan \
  --table-name $(terraform output -raw dynamodb_table_name)
```

You should see an entry with your filename and timestamp.

### Unit Tests

Run the comprehensive test suite:

```bash
# Install test dependencies
pip install pytest pytest-cov boto3 moto

# Run all tests
python -m pytest tests/ -v

# Run with coverage report
python -m pytest tests/ -v \
  --cov=lambda_trigger \
  --cov=lambda_writer \
  --cov=lambda_security_monitor \
  --cov-report=html
```

Expected output: **16 tests passed** with high code coverage (>85%).

### Comprehensive Testing Plan

#### Test 1: End-to-End Success Path

**Goal:** Verify the complete workflow works correctly.

```bash
# Upload a file
echo "Test 1" > file1.txt
aws --endpoint-url $ENDPOINT_URL s3 cp file1.txt \
  s3://$(terraform output -raw s3_bucket_name)/data/file1.txt \
  --sse aws:kms

# Wait 10 seconds for processing

# Check Step Functions execution
aws --endpoint-url $ENDPOINT_URL stepfunctions list-executions \
  --state-machine-arn $(terraform output -raw step_function_arn)
```

**Expected Result:** Step Function status = `SUCCEEDED`, entry created in DynamoDB.

#### Test 2: Concurrent Uploads

**Goal:** Verify the pipeline handles multiple uploads simultaneously.

```bash
# Upload second file immediately after first
echo "Test 2" > file2.txt
aws --endpoint-url $ENDPOINT_URL s3 cp file2.txt \
  s3://$(terraform output -raw s3_bucket_name)/data/file2.txt \
  --sse aws:kms

# Wait 10 seconds for processing

# Verify both entries exist
aws --endpoint-url $ENDPOINT_URL dynamodb scan \
  --table-name $(terraform output -raw dynamodb_table_name) \
  --query "Count" \
  --output text
```

**Expected Result:** Count = 2, both Step Function executions succeeded.

#### Test 3: Input Validation (Security)

**Goal:** Verify path traversal protection works.

**Note:** This test behaves differently in LocalStack vs real AWS.

**In LocalStack:**

```bash
# LocalStack allows this upload (less strict validation)
echo "Malicious" > bad.txt
aws --endpoint-url $ENDPOINT_URL s3 cp bad.txt \
  s3://$(terraform output -raw s3_bucket_name)/../etc/passwd \
  --sse aws:kms

# Check Lambda logs - you'll see the validation catch it
aws --endpoint-url $ENDPOINT_URL logs tail \
  /aws/lambda/$(terraform output -raw trigger_lambda_name) \
  --follow
```

**Expected Result (LocalStack):** File uploads to S3 due to LocalStack limitations, but the Trigger Lambda detects and blocks the malicious path from further processing.

**In Real AWS:**

```bash
# Real AWS blocks this at the S3 API level
aws s3 cp bad.txt \
  s3://$(terraform output -raw s3_bucket_name)/../etc/passwd \
  --sse aws:kms
```

**Expected Result (Real AWS):** The AWS CLI returns an error immediately; the upload is rejected before it even reaches S3. AWS's API validation blocks path traversal.

**Why the difference?** Real AWS has stricter S3 key validation at the API level that prevents malformed paths from ever being created. LocalStack is more permissive, which actually lets you test the Lambda's input validation layer. Both approaches ultimately prevent the malicious path from being processed.

#### Test 4: Security Monitor

**Goal:** Verify the security scanner detects unencrypted resources.

```bash
# Create an unencrypted bucket
aws --endpoint-url $ENDPOINT_URL s3 mb s3://test-unencrypted-bucket

# Manually invoke the security monitor
aws --endpoint-url $ENDPOINT_URL lambda invoke \
  --function-name $(terraform output -raw lambda_security_monitor_function_name) \
  --log-type Tail \
  response-auditor-output.json

# View the results
cat response-auditor-output.json

# Check CloudWatch logs for detailed scan results
aws --endpoint-url $ENDPOINT_URL logs tail \
  /aws/lambda/$(terraform output -raw lambda_security_monitor_function_name)
```

**Expected Result:** Response shows detection of the unencrypted bucket, and an SNS alert is sent. The CloudWatch logs will contain detailed information about which resources failed the encryption check.

---

## Security Features

This architecture implements multiple layers of security controls:

- **Encryption:** All data encrypted at rest using AWS KMS (separate keys for S3, DynamoDB, and SNS) and in transit using TLS
- **Input Validation:** Lambda functions validate all inputs to prevent path traversal, null byte injection, and other attacks
- **Least Privilege IAM:** Each service has only the minimum permissions needed for its specific operations
- **Proactive Monitoring:** CloudWatch alarms for errors and throttling, plus automated daily security scans
- **Data Lifecycle:** S3 objects expire after 90 days; DynamoDB has point-in-time recovery enabled
- **Network Security:** S3 public access blocked, HTTPS-only enforced, Lambda functions isolated

---

## Troubleshooting

### Issue: Terraform Hangs During Apply

**Symptoms:** Terraform gets stuck creating `aws_dynamodb_table` or `aws_cloudwatch_log_group` resources and shows no progress for several minutes.

**Cause:** LocalStack 1.3.1 has known bugs with DynamoDB point-in-time recovery and CloudWatch log group creation.

**Solution:**

```bash
# Stop the hanging Terraform process (Ctrl+C)

# Update docker-compose.yml to use LocalStack 3.0 or newer
# Change: image: localstack/localstack:1.3.1
# To:     image: localstack/localstack:3.0

# Restart LocalStack with fresh state
docker-compose down -v
docker-compose up -d

# Clean up partial Terraform state
terraform destroy -auto-approve

# Retry the deployment
terraform apply
```

---

## Known Limitations

### LocalStack vs Real AWS Behavior

This project was developed and tested on both LocalStack (for local development) and real AWS (for production validation). There are some important behavioral differences:

#### S3 Bucket Policy Enforcement

**The Implementation:**

The Terraform code includes a bucket policy that explicitly denies any upload without KMS encryption:

```hcl
{
  Effect = "Deny"
  Action = "s3:PutObject"
  Condition = {
    StringNotEquals = {
      "s3:x-amz-server-side-encryption" = "aws:kms"
    }
  }
}
```

**In Real AWS:**
This policy works exactly as intended. Any attempt to upload a file without the `--sse aws:kms` flag results in a `403 Forbidden` error, and the upload is rejected immediately.

```bash
# This fails in real AWS
aws s3 cp file.txt s3://bucket-name/file.txt
# Error: Access Denied (403)

# This succeeds in real AWS
aws s3 cp file.txt s3://bucket-name/file.txt --sse aws:kms
# Upload successful
```

**In LocalStack (versions 1.3.1 and earlier):**
The bucket policy is stored correctly but not enforced during `PutObject` operations. Uploads succeed even without the `--sse aws:kms` flag. This is a known limitation of LocalStack's S3 emulation.

```bash
# This succeeds in LocalStack (but shouldn't)
aws --endpoint-url http://localhost:4566 s3 cp file.txt s3://bucket-name/file.txt
# Upload successful (policy not enforced)
```

**What This Means:**
- The Terraform configuration is correct and production-ready
- Security testing of the bucket policy requires a real AWS environment
- The policy was successfully verified in a real AWS sandbox account
- LocalStack is still valuable for testing the workflow logic and Lambda functions

**Recommendation:** Use LocalStack for rapid development and workflow testing, but perform final security validation in a real AWS sandbox account before production deployment.

### LocalStack Version Compatibility

**Tested Versions:**

| Version | Status | Notes |
|---------|--------|-------|
| LocalStack 3.0+ | ✅ Recommended | All features work correctly |
| LocalStack 1.3.1 | ⚠️ Limited | DynamoDB PITR may cause hangs; bucket policies not enforced |
| Real AWS | ✅ Full Support | All features work as designed |

**Known Issues in LocalStack 1.3.1:**
- DynamoDB `point_in_time_recovery` attribute can cause Terraform to hang during `apply`
- S3 bucket policies with `Deny` effects are not enforced
- CloudWatch log group creation occasionally times out

**Recommended Setup:**
- Development and testing: LocalStack 3.0+
- Security validation: Real AWS sandbox account
- Production deployment: Real AWS

---

## Assignment Requirements

This section maps each assignment requirement to its implementation in the codebase:

### 1. End-to-End Architecture Implementation

**Requirement:** Build a serverless, event-driven architecture with S3 → Lambda → Step Functions → DynamoDB flow.

**Implementation:**
- `s3.tf` - S3 bucket configured with event notification that triggers on object creation
- `lambda_trigger.tf` - Trigger Lambda that receives S3 events and initiates workflow
- `step_functions.tf` - State machine that orchestrates the pipeline with retry logic
- `lambda_writer.tf` - Writer Lambda that persists metadata to DynamoDB
- `dynamodb.tf` - DynamoDB table with composite primary key for metadata storage

**Verification:** Upload a file to S3 and observe the automatic end-to-end flow through CloudWatch logs.

### 2. Secure Architecture (SSE, KMS)

**Requirement:** Implement encryption at rest using AWS KMS with server-side encryption.

**Implementation:**
- `kms.tf` - Three separate customer-managed KMS keys with automatic annual rotation enabled
- `s3.tf` - Bucket policy enforces KMS encryption on all uploads with explicit deny rule
- `dynamodb.tf` - Table encrypted using dedicated KMS CMK, separate from S3 key
- `sns.tf` - SNS topic encrypted with dedicated KMS CMK

**Verification:** Attempt to upload a file without `--sse aws:kms` flag (fails in real AWS).

### 3. DynamoDB Attributes

**Requirement:** DynamoDB table must store "Filename" and "Upload Timestamp" attributes.

**Implementation:**
```hcl
attribute {
  name = "Filename"
  type = "S"  # String
}

attribute {
  name = "UploadTimestamp"
  type = "S"  # String (ISO 8601 format)
}

hash_key  = "Filename"        # Partition key
range_key = "UploadTimestamp" # Sort key
```

**Verification:** Query DynamoDB after file upload to see both attributes populated.

### 4. S3 Object Expiration (90 Days)

**Requirement:** Configure S3 lifecycle policy to automatically expire objects after 90 days.

**Implementation in `s3.tf`:**
```hcl
lifecycle_rule {
  enabled = true
  
  expiration {
    days = 90
  }
  
  noncurrent_version_expiration {
    noncurrent_days = 90
  }
}
```

**Verification:** Run `aws s3api get-bucket-lifecycle-configuration` to view the policy.

### 5. Least Privilege IAM

**Requirement:** Apply principle of least privilege - services should have only the minimum permissions required.

**Implementation in `iam.tf`:**
- Each Lambda has a dedicated execution role
- Policies use specific resource ARNs (no wildcards like `*`)
- Actions are limited to exact operations needed (e.g., `dynamodb:PutItem` only, not `dynamodb:*`)
- KMS key policies include `kms:ViaService` conditions to restrict key usage to specific services
- Step Functions can invoke only the specific Writer Lambda by ARN

**Verification:** Review IAM policies with `aws iam get-role-policy` and verify no overly permissive actions.

### 6. Security Alert on Unencrypted Resources

**Requirement:** Implement automated detection and alerting for any unencrypted S3 buckets or DynamoDB tables.

**Implementation:**
- `lambda_security_monitor.tf` - Lambda function that scans all resources
- `cloudwatch.tf` - EventBridge rule triggers the Lambda every 24 hours
- `lambda_security_monitor/index.py` - Python code that checks encryption status
- `sns.tf` - SNS topic receives alerts when unencrypted resources are found

**Scan Logic:**
- Calls `s3:GetBucketEncryption` for all buckets
- Calls `dynamodb:DescribeTable` and checks `SSEDescription` field
- Publishes detailed SNS message with list of non-compliant resources

**Verification:** Create an unencrypted bucket and manually invoke the monitor Lambda.

### 7. Error Handling

**Requirement:** Implement graceful error handling for DynamoDB write failures and other issues.

**Implementation in `step_functions.tf`:**
```json
"Retry": [
  {
    "ErrorEquals": ["States.ALL"],
    "IntervalSeconds": 2,
    "MaxAttempts": 3,
    "BackoffRate": 2.0
  }
],
"Catch": [
  {
    "ErrorEquals": ["States.ALL"],
    "ResultPath": "$.error",
    "Next": "NotifyFailure"
  }
]
```

**Implementation in Lambda functions:**
- All functions wrapped in try-except blocks
- Validation errors return structured error responses
- Errors logged to CloudWatch with full context
- SNS notification sent on unrecoverable failures

**Verification:** Trigger an error by providing invalid input and verify retry behavior in Step Functions console.

### 8. Logging

**Requirement:** Comprehensive logging to capture event details and Step Functions execution status.

**Implementation:**
- `cloudwatch.tf` - Log groups created for all Lambda functions with 7-day retention
- `step_functions.tf` - State machine logging enabled at `ALL` level, logging to CloudWatch
- All Lambda functions use structured logging with JSON format
- Logs include: request IDs, input parameters, execution duration, error details

**Log Contents:**
- S3 event details (bucket name, object key, timestamp)
- Validation results and any security violations detected
- DynamoDB write operations and response metadata
- Step Functions state transitions and decision outcomes

**Verification:** Run `aws logs tail /aws/lambda/<function-name> --follow` during testing.

### 9. Unit Testing

**Requirement:** Include unit tests to ensure code quality and reliability.

**Implementation:**
- `tests/test_lambda_trigger.py` - 6 unit tests for trigger Lambda
- `tests/test_lambda_writer.py` - 6 unit tests for writer Lambda
- `tests/test_security_monitor.py` - 4 unit tests for security monitor
- Total: 16 comprehensive unit tests covering success and failure paths

**Test Coverage:**
- Input validation (path traversal, null bytes, length limits)
- Successful execution paths
- Error handling and exception scenarios
- Mock AWS SDK calls using `moto` library
- Code coverage exceeds 85% across all functions

**Verification:** Run `python -m pytest tests/ -v --cov` to execute tests and generate coverage report.

---

## Cleanup

When you're finished testing, remove all resources to avoid unnecessary costs (in real AWS) or free up local resources (in LocalStack):

### Complete Cleanup

```bash
# Destroy all Terraform-managed infrastructure
terraform destroy -auto-approve

# Stop LocalStack container
docker-compose down

# Remove all LocalStack volumes and data (optional)
docker-compose down -v

# Remove generated Lambda zip files (optional)
rm -f lambda_trigger.zip lambda_writer.zip lambda_security_monitor.zip
```

### Partial Cleanup (Keep Infrastructure, Remove Data)

```bash
# Delete all objects in the S3 bucket
aws --endpoint-url $ENDPOINT_URL s3 rm \
  s3://$(terraform output -raw s3_bucket_name) \
  --recursive

# Clear all items from DynamoDB table
aws --endpoint-url $ENDPOINT_URL dynamodb scan \
  --table-name $(terraform output -raw dynamodb_table_name) \
  --query "Items[*].[Filename.S, UploadTimestamp.S]" \
  --output text | while read filename timestamp; do
    aws --endpoint-url $ENDPOINT_URL dynamodb delete-item \
      --table-name $(terraform output -raw dynamodb_table_name) \
      --key "{\"Filename\":{\"S\":\"$filename\"},\"UploadTimestamp\":{\"S\":\"$timestamp\"}}"
  done
```

### Verify Cleanup

```bash
# Check that no resources remain
terraform show

# Verify LocalStack is stopped
docker-compose ps

# Verify no volumes remain
docker volume ls | grep localstack
```

---

## Additional Resources

### AWS Documentation
- [AWS Step Functions Developer Guide](https://docs.aws.amazon.com/step-functions/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Amazon S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/)
- [DynamoDB Encryption at Rest](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html)

### Terraform Documentation
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS S3 Bucket Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket)
- [AWS Lambda Function Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [AWS Step Functions State Machine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine)

### LocalStack Documentation
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [LocalStack AWS Service Coverage](https://docs.localstack.cloud/references/coverage/)
- [LocalStack Configuration](https://docs.localstack.cloud/references/configuration/)

### Security Best Practices
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)

---
