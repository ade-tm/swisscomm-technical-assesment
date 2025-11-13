import json
import boto3
import os
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
# CRITICAL FIX: Explicitly set region_name='eu-central-1' to resolve botocore.exceptions.NoRegionError 
# during pytest collection.
s3 = boto3.client('s3', region_name='eu-central-1', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))
dynamodb = boto3.client('dynamodb', region_name='eu-central-1', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))
sns = boto3.client('sns', region_name='eu-central-1', endpoint_url=os.environ.get('AWS_ENDPOINT_URL'))

def check_s3_encryption():
    """
    Check all S3 buckets for encryption compliance.
    Flags buckets that are unencrypted OR are not using aws:kms.
    Returns a list of dictionaries with non-compliant bucket names and the reason.
    """
    s3_issues = []
    
    try:
        logger.info("Starting S3 encryption check...")
        response = s3.list_buckets()
        buckets = response.get('Buckets', [])
        logger.info(f"Found {len(buckets)} S3 buckets to check")
        
        for bucket in buckets:
            bucket_name = bucket['Name']
            try:
                # Get bucket encryption configuration
                encryption = s3.get_bucket_encryption(Bucket=bucket_name)
                rules = encryption['ServerSideEncryptionConfiguration']['Rules']
                algorithm = rules[0]['ApplyServerSideEncryptionByDefault']['SSEAlgorithm']
                
                # Logic: If it's not KMS, it's non-compliant
                if algorithm != 'aws:kms':
                    logger.warning(f"ALERT: Bucket '{bucket_name}' is not using KMS (using {algorithm})")
                    s3_issues.append({
                        "name": bucket_name,
                        "reason": f"is not encrypted with a KMS key (uses default {algorithm} encryption)."
                    })
                else:
                    logger.info(f"Bucket '{bucket_name}' is compliant (using KMS)")
                    
            except ClientError as e:
                error_code = e.response['Error']['Code']
                if error_code == 'ServerSideEncryptionConfigurationNotFoundError':
                    # This means the bucket has no encryption configuration at all (legacy/rare)
                    logger.warning(f"ALERT: Bucket '{bucket_name}' has NO encryption configuration!")
                    s3_issues.append({
                        "name": bucket_name,
                        "reason": "has no encryption configuration at all."
                    })
                else:
                    # Some other error, like permission denied (shouldn't happen with correct IAM)
                    logger.error(f"Error checking bucket '{bucket_name}': {str(e)}")
        
        return s3_issues
        
    except ClientError as e:
        logger.error(f"Error listing S3 buckets: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error checking S3 encryption: {str(e)}", exc_info=True)
        raise

def check_dynamodb_encryption():
    """
    Check all DynamoDB tables for encryption configuration.
    Returns a list of unencrypted table names.
    """
    unencrypted_tables = []
    try:
        logger.info("Starting DynamoDB encryption check...")
        response = dynamodb.list_tables()
        table_names = response.get('TableNames', [])
        logger.info(f"Found {len(table_names)} DynamoDB tables to check")
        
        for table_name in table_names:
            try:
                table_desc = dynamodb.describe_table(TableName=table_name)
                sse_desc = table_desc['Table'].get('SSEDescription')
                
                # Check if encryption is enabled (Status must be ENABLED)
                if not sse_desc or sse_desc.get('Status') != 'ENABLED':
                    unencrypted_tables.append(table_name)
                    logger.warning(f"ALERT: Table '{table_name}' is NOT encrypted!")
                else:
                    logger.info(f"Table '{table_name}' is encrypted")
            except ClientError as e:
                logger.error(f"Error checking table '{table_name}': {str(e)}")
        
        return unencrypted_tables
        
    except ClientError as e:
        logger.error(f"Error listing DynamoDB tables: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error checking DynamoDB encryption: {str(e)}", exc_info=True)
        raise

def send_alert(issues_list):
    """
    Send SNS alert with security issues, using the friendly, conversational tone.
    """
    
    subject = "Audit Complete: Resources Need KMS Encryption Review"
    
    # --- The Conversational, Human-Toned Message ---
    message_intro = "Hi team,\n\nOur automated security auditor just finished its daily scan and found a few resources that don't seem to be using our preferred KMS encryption. Don't panic! Most of these are probably just using default AWS encryption, but our policy is to use KMS for everything.\n\nHere's a breakdown of what it found:\n\n"
    
    # The issues_list already contains the specific, formatted strings 
    message_body = "\n".join(f"• {issue}" for issue in issues_list)
    
    message_footer = "\n\nPlease take a look at these when you get a chance so we can stay compliant. If these are low-priority or dev resources, no rush.\n\nThanks!\n\n- Your Friendly Security Bot"
    
    full_message = message_intro + message_body + message_footer
    
    # Send SNS publish call
    # Note: SNS client is initialized globally at the top of the file
    response = sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject=subject,
        Message=full_message
    )
    
    logger.info(f"Conversational alert sent successfully. MessageId: {response['MessageId']}")


def handler(event, context):
    """
    Lambda handler to scan for security issues and send alerts.
    """
    try:
        logger.info("Starting security scan...")
        
        # This will be our master list of nicely formatted strings
        all_issues = []
        
        # Check S3 buckets
        s3_results = check_s3_encryption()
        for issue in s3_results:
            # Format the output into the final detailed string
            all_issues.append(f"S3 Bucket '{issue['name']}' {issue['reason']}")
        
        # Check DynamoDB tables
        dynamo_results = check_dynamodb_encryption()
        for table_name in dynamo_results:
            all_issues.append(f"DynamoDB Table '{table_name}' is not encrypted.")
        
        # Send alert if issues found
        if all_issues:
            logger.warning(f"Found {len(all_issues)} security issues")
            send_alert(all_issues)
        else:
            logger.info("Security scan completed. No issues found.")
        
        return {
            'statusCode': 200,
            'issues_found': len(all_issues),
            'body': json.dumps({
                'message': 'Security scan completed',
                'issues': all_issues
            })
        }
        
    except Exception as e:
        logger.error(f"Security scan failed: {str(e)}", exc_info=True)
        
        # Try to send alert about scan failure
        try:
            sns.publish(
                TopicArn=os.environ['SNS_TOPIC_ARN'],
                Subject="⚠️ Security Scan FAILED",
                Message=f"The scheduled security scan encountered a critical error and could not complete:\n\n{str(e)}"
            )
        except:
            pass
        
        raise