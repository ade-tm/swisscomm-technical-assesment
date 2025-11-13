# S3 Bucket Security Hardening - CloudFormation Assignment

## What This Is

This project takes a basic S3 bucket CloudFormation template and transforms it into a production-ready, security-hardened solution. The original template had several security gaps identified by cfn-nag, this fixes all of them and goes further by implementing AWS security best practices.

## The Problem

The original template created a simple S3 bucket with zero security controls. Running it through cfn-nag revealed three major warnings:

- **W41**: No encryption configured
- **W35**: Access logging not enabled  
- **W51**: Missing bucket policy

Beyond just fixing these warnings, the bucket was vulnerable to common S3 security issues like accidental public exposure, data loss from deletions, and unnecessary storage costs from abandoned uploads.

## The Solution

I rebuilt the template with a comprehensive security approach that implements defense-in-depth. Instead of just patching the three warnings, I created a proper two-bucket architecture with extensive security controls.

### Architecture

The solution uses a two-bucket design that separates data from audit logs:

**Main Bucket** (`mytest-s3`)  
This is where your actual data lives. It's locked down with multiple layers of security:
- Everything stored here is encrypted with AES256
- Versioning is on, so you can recover from accidental deletions
- Public access is blocked at four different levels
- A bucket policy enforces HTTPS-only connections
- Lifecycle rules automatically move old data to cheaper storage classes and clean up old versions

**Logging Bucket** (`mytest-logs-s3`)  
This bucket collects access logs from the main bucket. Every time someone interacts with the main bucket - uploading, downloading, listing files - that activity gets recorded here.
- Also encrypted with AES256
- Also has versioning enabled
- Also blocks all public access
- Logs are automatically deleted after 90 days to control costs

The main bucket sends its access logs to the logging bucket. This separation is important - if someone compromises your main bucket, they can't easily cover their tracks by deleting the logs, because those logs are stored elsewhere.

## Security Features

### What I Fixed (cfn-nag Requirements)

1. **Encryption** - All data is encrypted at rest using AES256
2. **Access Logging** - Every request is logged to a separate bucket
3. **Bucket Policy** - HTTPS-only access enforced through IAM policies

### What I Added (Best Practices)

4. **Versioning** - Recover from accidental deletions or overwrites
5. **Public Access Block** - Four-layer protection against public exposure
6. **Lifecycle Policies** - Automatic data management to reduce costs
7. **Enhanced Policies** - Additional protections beyond basic HTTPS

### Why These Matter

**Encryption**: Without encryption, anyone with physical access to AWS servers could theoretically read your data. Encryption at rest is basically table stakes for any serious deployment.

**Versioning**: I've seen too many stories of critical data getting accidentally deleted. With versioning, you can recover from mistakes - it's like having an undo button for your S3 bucket.

**Public Access Block**: This is the big one. Most major S3 data breaches happen because someone accidentally made a bucket public. The Public Access Block feature adds four different checks to prevent this, even if someone misconfigures ACLs or policies later.

**Lifecycle Policies**: Storage costs add up fast. After 30 days, data moves to cheaper "Infrequent Access" storage. After 90 days, it goes to Glacier for long-term archival. Old versions get cleaned up automatically.

## Project Structure
```
.
├── stack.template          # The CloudFormation template
├── docker-compose.yml      # LocalStack setup for testing
└── README.md              # This file
```

## Getting Started

### Prerequisites

You'll need:
- Docker and Docker Compose
- AWS CLI
- A few minutes of patience while LocalStack starts up

### Running the Stack

1. **Start LocalStack**
```bash
   docker-compose up -d
```
   

2. **Configure AWS CLI for LocalStack**
```bash
   export AWS_ACCESS_KEY_ID=foobar
   export AWS_SECRET_ACCESS_KEY=foobar
   export AWS_REGION=eu-central-1
```
   
   (These are dummy credentials - LocalStack doesn't actually validate them)

3. **Deploy the Stack**
```bash
   aws --endpoint-url http://localhost:4566 \
     cloudformation create-stack \
     --stack-name my-secure-bucket \
     --template-body file://stack.template \
     --parameters ParameterKey=BucketName,ParameterValue=test
```

4. **Verify It Worked**
```bash
   aws --endpoint-url http://localhost:4566 \
     cloudformation describe-stacks \
     --stack-name my-secure-bucket \
     --query 'Stacks[0].StackStatus'
```
   
   You should see `CREATE_COMPLETE`

### Testing It Out

Upload a file:
```bash
echo "Hello, secure bucket!" > test.txt
aws --endpoint-url http://localhost:4566 \
  s3 cp test.txt s3://test-s3/
```

List files:
```bash
aws --endpoint-url http://localhost:4566 \
  s3 ls s3://test-s3/
```

Download it back:
```bash
aws --endpoint-url http://localhost:4566 \
  s3 cp s3://test-s3/test.txt downloaded.txt
```

### Cleaning Up

Delete the stack:
```bash
aws --endpoint-url http://localhost:4566 \
  cloudformation delete-stack \
  --stack-name my-secure-bucket
```

Stop LocalStack:
```bash
docker-compose down -v
```

The `-v` flag removes volumes, giving you a clean slate next time.

## Security Validation

### cfn-nag Results

Running cfn-nag against this template:
```bash
docker logs cfn-nag
```

Results:
```
Failures count: 0
Warnings count: 0
```

Clean bill of health.

### What Each Control Does

| Control | What It Prevents | Real-World Impact |
|---------|-----------------|-------------------|
| Encryption | Unauthorized data access | If someone steals an AWS hard drive, your data is useless to them |
| Versioning | Accidental deletions | That "oh crap" moment when you delete the wrong file becomes recoverable |
| Public Access Block | Data breaches | Prevents the horror stories you read about in the news |
| HTTPS-Only Policy | Man-in-the-middle attacks | Your data can't be intercepted in transit |
| Lifecycle Policies | Runaway costs | Storage costs don't spiral out of control |

## Cost Optimization

The template includes several cost-saving features:

- **Bucket Keys**: Reduces encryption costs by ~99%
- **Storage Class Transitions**: Moves old data to cheaper storage automatically
- **Lifecycle Cleanup**: Deletes old versions after 90 days
- **Multipart Upload Cleanup**: Prevents abandoned uploads from accumulating

In a real production environment with significant storage, these features could save hundreds or thousands of dollars per month.

## LocalStack Limitations

Not everything works perfectly in LocalStack. Some API calls that work in real AWS don't work here:

- `get-bucket-encryption` - Returns an error even though encryption is configured
- Some lifecycle transitions - Not fully simulated
- Cross-region replication - Not available

**This is normal.** LocalStack is great for testing CloudFormation syntax and basic functionality, but it's not a perfect AWS clone. The template itself is correct and would work perfectly in real AWS.

## Design Decisions

### Why Two Buckets?

I could have used just one bucket, but separating logs from data is a security best practice. If your main bucket gets compromised, you don't want the attacker to be able to delete the access logs showing what they did. Plus, logs have different lifecycle requirements - you typically want to delete them after some time, but keep your actual data longer.

### Why AES256 Instead of KMS?

AWS offers two encryption options: SSE-S3 (AES256) and SSE-KMS (custom keys). I went with AES256 because:
- It's simpler (no key management required)
- It's cheaper (no KMS charges)
- It's perfectly adequate for most use cases

For scenarios requiring key rotation, audit trails, or cross-account access, KMS would be better. But for a general-purpose secure bucket, AES256 hits the sweet spot.

### Why Suppress W35 on the Logging Bucket?

cfn-nag wants every bucket to have access logging. But logging the logging bucket creates infinite recursion - you'd need a third bucket to log the logging bucket, then a fourth to log that one, and so on.

The suppression is properly documented with a reason explaining this is intentional, not an oversight. This is the standard approach everyone uses.

## What I Learned

This assignment really drove home how much security comes from layering multiple controls. Any single control can fail - a misconfiguration, a permission issue, a bug in AWS. But when you stack versioning + encryption + public access blocks + bucket policies + logging, you create a system that's resilient to failure.

I also learned that good security and cost optimization aren't mutually exclusive. The lifecycle policies reduce costs while the versioning provides protection. It's possible to be both secure and economical.

## Future Improvements

If I were taking this to a real production environment, I'd consider adding:

- **Cross-Region Replication**: For disaster recovery
- **Object Lock**: For compliance requirements (WORM storage)
- **AWS CloudTrail Integration**: For even more detailed audit logging  
- **S3 Inventory**: For periodic audits of what's in the bucket
- **CloudWatch Alarms**: To alert on unusual access patterns

But for the scope of this assignment, what's here is solid.

## References

- [AWS S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [cfn-nag Rules](https://github.com/stelligent/cfn_nag)
- [AWS Well-Architected Framework - Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)
- [LocalStack Documentation](https://docs.localstack.cloud/)

## Questions?

If something isn't working or doesn't make sense, the most likely culprits are:

1. LocalStack not fully started (wait for the "preload_services" message)
2. AWS CLI not pointing to LocalStack (check the `--endpoint-url` flag)
3. Environment variables not set (check `AWS_ACCESS_KEY_ID` etc.)

For LocalStack issues, `docker-compose logs -f localstack` is your friend.

---
