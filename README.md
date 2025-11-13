# Swisscomm Technical Assignments Submission

Hey there! This repository contains my solutions for the two technical assignments.

## What's Inside

I've completed both assignments and organized them into separate folders:

### 📁 cloudformation/
My solution for the CloudFormation assignment. The goal was to take a basic S3 bucket template and add proper security controls based on cfn-nag findings. I ended up implementing a pretty comprehensive security setup with encryption, logging, versioning, and a bunch of other AWS best practices.

Check out the README inside that folder for the full breakdown of what I built and how to run it.

### 📁 terraform/
My solution for the Terraform assignment. This one builds a serverless file ingestion pipeline using AWS services - S3, Lambda, Step Functions, and DynamoDB. It's a complete event-driven architecture with security monitoring and CloudWatch alarms.

There's a detailed README in that folder too that walks through everything.

## Structure
```
.
├── cloudformation/                 # CloudFormation S3 security assignment
│   ├── stack.template              # The CloudFormation template
│   ├── docker-compose.yml          # LocalStack setup
│   ├── README.md                   # Detailed docs for this assignment
│   └── .gitignore
│
├── terraform/                      # Terraform serverless pipeline assignment
│   ├── docker-compose.yml          # LocalStack container configuration
│   ├── README.md                   # Project documentation and test plan
│   │
│   ├── cloudwatch.tf               # CloudWatch Alarms for monitoring
│   ├── dynamodb.tf                 # DynamoDB table definition
│   ├── iam.tf                      # All IAM Roles and Policies
│   ├── kms.tf                      # KMS Key definitions
│   ├── lambda_security_monitor.tf  # Security Auditor Lambda
│   ├── lambda_trigger.tf           # S3 Trigger Lambda
│   ├── lambda_writer.tf            # DynamoDB Writer Lambda
│   ├── outputs.tf                  # Resource outputs
│   ├── provider.tf                 # AWS Provider configuration
│   ├── s3.tf                       # S3 Bucket configuration
│   ├── sns.tf                      # SNS Topic and Subscription
│   ├── step_functions.tf           # Step Functions State Machine
│   ├── variables.tf                # Project-wide variables
│   │
│   ├── lambda_security_monitor/    # Security Auditor Lambda code
│   │   └── index.py
│   │
│   ├── lambda_trigger/             # S3 Trigger Lambda code
│   │   └── index.py
│   │
│   ├── lambda_writer/              # DynamoDB Writer Lambda code
│   │   └── index.py
│   │
│   ├── scripts/                    # Build and packaging scripts
│   │   └── package_lambdas.sh
│   │
│   └── tests/                      # Unit tests
│       ├── __init__.py
│       ├── test_lambda_trigger.py
│       ├── test_lambda_writer.py
│       └── test_security_monitor.py
│
└── README.md                       # This file
```

## How to Use This

Each assignment is self-contained in its own folder. Just head into whichever one you want to check out and follow the README there. They've got everything you need - prerequisites, setup instructions, testing steps, the whole deal.

## Assignment Completion

Both assignments have been tested and validated:
- **CloudFormation**: Template passes cfn-nag with 0 warnings, implements comprehensive S3 security
- **Terraform**: Serverless pipeline fully functional with security monitoring and error handling
- Both solutions include comprehensive documentation and testing instructions

## Quick Start
```bash
# CloudFormation assignment
cd cloudformation/
cat README.md

# Terraform assignment
cd terraform/
cat README.md
```

## Notes

Each folder has its own `.gitignore` to keep things clean. I've made sure not to commit any credentials, LocalStack data, or temporary test files. Both solutions have been tested locally using LocalStack and follow AWS best practices.

If you have any questions about either solution or run into any issues trying them out, feel free to reach out!

---

**Submitted by**: Adedotun Ojolowo  
**Date**: November 2025