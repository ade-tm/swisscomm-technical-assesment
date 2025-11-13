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

## Overview

This project implements a secure, serverless pipeline that automatically processes files uploaded to S3. Every file upload triggers a workflow that validates the input, tracks metadata in DynamoDB, and maintains continuous security compliance through automated auditing.

### What This Solution Does

- **Processes file uploads** automatically when files land in S3
- **Tracks metadata** (filename and timestamp) in an encrypted DynamoDB table
- **Enforces encryption** across all services using AWS KMS
- **Monitors security** with a scheduled Lambda that scans for unencrypted resources
- **Handles errors gracefully** with retry logic and SNS notifications
- **Validates all inputs** to prevent common security vulnerabilities

### Why This Approach?

The architecture follows AWS best practices:
- **Least privilege access** - each service gets only the permissions it needs
- **Defense in depth** - multiple layers of security controls
- **Fail-safe defaults** - everything is encrypted unless explicitly configured otherwise
- **Audit everything** - comprehensive logging and monitoring throughout

## Architecture

### High-Level Flow

```
User uploads file
    ↓
S3 Bucket (encrypted)
    ↓
S3 Event Notification
    ↓
Lambda: Trigger Function
    ↓
Step Functions (orchestrator)
    ↓
Lambda: Writer Function
    ↓
DynamoDB (encrypted)
```

### Background Security Monitoring

```
CloudWatch Event (every 24 hours)
    ↓
Lambda: Security Monitor
    ↓
Scans all S3 buckets & DynamoDB tables
    ↓
SNS Alert (if issues found)
```

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

## Prerequisites

Before getting started, make sure you have these installed:

- **Docker & Docker Compose** - for running LocalStack
- **Terraform** (v1.0+) - for infrastructure provisioning
- **AWS CLI** - for testing and validation
- **Python 3.11+** - for Lambda functions and unit tests
- **Bash** - for running helper scripts

## Getting Started

### 1. Start LocalStack

LocalStack provides a local AWS environment for testing without incurring costs.

```bash
# Start LocalStack in the background
docker-compose up -d

# Verify it's running
docker-compose logs -f localstack | grep "Ready"
```

You should see: `Ready.` in the logs when LocalStack is fully initialized.

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

**Note:** This test behaves differently in LocalStack vs real AWS:

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

**Expected Result (LocalStack):** File uploads to S3 due to Local stack limitations.

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
aws --endpoint-url "$ENDPOINT_URL" lambda invoke \
  --function-name "$(terraform output -raw lambda_security_monitor_function_name)" \
  --log-type Tail response-auditor-output.json \
| jq -r '.LogResult' | base64 --decode

**Expected Result:** Response shows detection of an unencrypted bucket, and an SNS alert is sent.


## Security Features

### 1. Encryption Everywhere

**S3 Buckets:**
- Server-side encryption with KMS
- Bucket policy denies unencrypted uploads
- HTTPS-only access enforced

**DynamoDB:**
- Encryption at rest with KMS
- Point-in-time recovery enabled
- Separate encryption key from S3

**SNS:**
- Topic encrypted with KMS
- Separate encryption key

**Why separate keys?** If one key is compromised, the blast radius is limited.

### 2. Input Validation

All Lambda functions validate inputs to prevent:
- **Path traversal attacks** (`../../../etc/passwd`)
- **Null byte injection** (`file\x00.txt`)
- **Excessively long filenames** (>1024 chars)
- **Empty or whitespace-only names**

### 3. Least Privilege IAM

Each IAM role has the minimum permissions needed:

**Trigger Lambda:**
- Can only start the specific Step Function
- Can only write to its own CloudWatch log group

**Writer Lambda:**
- Can only write (`PutItem`) to the Files table
- Cannot read, update, or delete
- Can only use DynamoDB KMS key via ViaService condition

**Security Monitor:**
- Read-only access to resource configurations
- Can publish to SNS topic only
- Cannot modify any resources

**Step Functions:**
- Can only invoke the specific Writer Lambda
- Can publish to SNS for error notifications

### 4. Proactive Monitoring

**CloudWatch Alarms:**
- Lambda errors (>3 in 5 minutes)
- Lambda throttling (>5 in 5 minutes)
- Step Functions failures (>2 in 5 minutes)
- DynamoDB throttling (>5 in 5 minutes)

**Security Scanner:**
- Runs every 24 hours automatically
- Scans all S3 buckets for encryption
- Scans all DynamoDB tables for encryption
- Sends immediate SNS alert if issues found

### 5. Data Lifecycle Management

**S3 Lifecycle Policy:**
- Current objects expire after 90 days
- Noncurrent (versioned) objects expire after 90 days
- Reduces storage costs and limits data exposure

**DynamoDB:**
- Point-in-time recovery (restore to any point in last 35 days)
- Continuous backups

## Troubleshooting

### Issue: Terraform Hangs During Apply

**Symptoms:** Terraform gets stuck creating `aws_dynamodb_table` or `aws_cloudwatch_log_group`.

**Cause:** LocalStack 1.3.1 has bugs with these resources.

**Solution:**
```bash
# Stop Terraform (Ctrl+C)
# Update docker-compose.yml to use LocalStack 3.0
# Then:
docker-compose down -v
docker-compose up -d
terraform destroy
terraform apply
```

### Issue: Lambda Function Not Triggering

**Symptoms:** File uploaded to S3, but nothing happens.

**Check:**
```bash
# Verify S3 notification is configured
aws --endpoint-url $ENDPOINT_URL s3api \
  get-bucket-notification-configuration \
  --bucket $(terraform output -raw s3_bucket_name)

# Check Lambda logs
aws --endpoint-url $ENDPOINT_URL logs tail \
  /aws/lambda/$(terraform output -raw trigger_lambda_name)
```

### Issue: DynamoDB Write Fails

**Symptoms:** Step Function shows error about DynamoDB access denied.

**Check:**
```bash
# Verify the Lambda role has permissions
aws --endpoint-url $ENDPOINT_URL iam get-role-policy \
  --role-name $(terraform output -raw writer_lambda_role_name) \
  --policy-name $(terraform output -raw writer_lambda_policy_name)
```

### Issue: KMS Access Denied

**Symptoms:** Error mentions `KMS.AccessDeniedException`.

**Fix:** This is usually a KMS key policy issue. Check `kms.tf` to ensure the Lambda role is granted access to the key.

## Known Limitations

### LocalStack vs Real AWS

This project was developed and tested on both LocalStack (for local development) and real AWS. There's one important difference:

**S3 Bucket Policy Enforcement:**

In the code, we have a bucket policy that explicitly denies any upload without KMS encryption:

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

- **In Real AWS:** This works perfectly. Uploads without `--sse aws:kms` are rejected with `403 Forbidden`.
- **In LocalStack (1.3.1):** This policy is not enforced. Uploads succeed even without the flag.

**What this means:**
- The code is correct and production-ready
- Security testing in LocalStack has limitations
- The policy was verified working in a real AWS sandbox account

### LocalStack Version Compatibility

**Tested Versions:**
- LocalStack 3.0+ - All features work
- LocalStack 1.3.1 - Point-in-time recovery may cause hangs
- Real AWS - All features work perfectly

**Recommendation:** Use LocalStack 3.0+ for local testing, or deploy to real AWS for full functionality.

## Assignment Requirements

This section maps the assignment requirements to the implemented solution:

### 1. End-to-End Architecture Implementation

**Requirement:** Build serverless, event-driven architecture with S3 → Lambda → Step Functions → DynamoDB.

**Implementation:**
- `s3.tf` - S3 bucket with event notification
- `lambda_trigger.tf` - Triggered by S3 events
- `step_functions.tf` - Orchestrates the workflow
- `lambda_writer.tf` - Writes to DynamoDB
- `dynamodb.tf` - Stores file metadata

### 2. Secure Architecture (SSE, KMS)

**Requirement:** Implement encryption and KMS.

**Implementation:**
- `kms.tf` - Three separate KMS keys with rotation enabled
- `s3.tf` - S3 bucket policy enforces KMS encryption
- `dynamodb.tf` - Table encrypted with dedicated KMS key
- `sns.tf` - SNS topic encrypted

### 3. DynamoDB Attributes

**Requirement:** Table with "Filename" and "Upload Timestamp" attributes.

**Implementation:**
```hcl
hash_key  = "Filename"        # Partition key
range_key = "UploadTimestamp" # Sort key
```

### 4. S3 Object Expiration (90 Days)

**Requirement:** Ensure old objects expire after 90 days.

**Implementation:**
```hcl
expiration {
  days = 90
}
noncurrent_version_expiration {
  noncurrent_days = 90
}
```

### 5. Least Privilege IAM

**Requirement:** Services should have minimum necessary permissions.

**Implementation:**
- `iam.tf` - Granular policies with resource-specific ARNs
- Each role has only the actions it needs
- Condition keys restrict KMS usage to specific services

### 6. Security Alert on Unencrypted Resources

**Requirement:** Alert security team if unencrypted S3 bucket or DynamoDB table found.

**Implementation:**
- `lambda_security_monitor.tf` - Scheduled Lambda (every 24 hours)
- Scans all S3 buckets and DynamoDB tables
- Publishes to SNS if unencrypted resources detected

### 7. Error Handling

**Requirement:** Graceful handling of failures and DynamoDB write errors.

**Implementation:**
- Step Functions retry logic (3 attempts, exponential backoff)
- Catch blocks route errors to SNS notifications
- Lambda functions have try-catch with detailed logging

### 8. Logging

**Requirement:** Capture event details and Step Function execution status.

**Implementation:**
- All Lambdas log to CloudWatch
- Step Functions logging enabled at ALL level
- Structured logging with event details

### 9. Unit Testing

**Requirement:** Unit tests to ensure quality and reliability.

**Implementation:**
- `tests/` directory with comprehensive test suite
- 16 unit tests covering all Lambda functions
- Tests for validation, error handling, and success paths
- >85% code coverage

## Cleanup

When you're done testing, clean up all resources:

```bash
# Destroy all Terraform-managed resources
terraform destroy

# Stop and remove LocalStack
docker-compose down

# Remove volumes (optional - clears all LocalStack data)
docker-compose down -v
```

## Additional Resources

- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

