import json
import boto3
import os
import logging
from datetime import datetime, UTC

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
# CRITICAL FIX: Explicitly set region_name='eu-central-1' to resolve botocore.exceptions.NoRegionError 
# This forces the region to be present during module import for unit testing.
stepfunctions = boto3.client('stepfunctions', region_name='eu-central-1', endpoint_url=os.environ.get('ENDPOINT_URL'))

def validate_s3_key(key):
    """
    Validate S3 object key to prevent security issues (Path Traversal, Null Bytes, Length)
    """
    # 1. Path Traversal Check 
    if '..' in key or key.startswith('/'):
        raise ValueError(f"Invalid key path (path traversal attempt): {key}")
    
    # 2. Null Byte Check
    if '\x00' in key:
        raise ValueError(f"Key contains null bytes: {key}")
    
    # 3. Length Check
    if len(key) > 1024:
        raise ValueError(f"Key too long: {len(key)} characters (max: 1024)")
    
    if not key or not key.strip():
        raise ValueError("Key cannot be empty")
    
    logger.info(f"Key validation passed: {key}")
    return True

def handler(event, context):
    """
    Lambda handler to process S3 events and trigger Step Functions
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        execution_arns = []
        
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            event_time = record['eventTime']
            
            logger.info(f"Processing file: {key} from bucket: {bucket}")
            
            # Validate the S3 key. 
            validate_s3_key(key)
            
            # Prepare input for Step Functions
            step_function_input = {
                'bucket': bucket,
                'key': key,
                'timestamp': datetime.now(UTC).isoformat(),
                'event_time': event_time
            }
            
            # Start Step Function execution
            response = stepfunctions.start_execution(
                stateMachineArn=os.environ['STATE_MACHINE_ARN'],
                input=json.dumps(step_function_input)
            )
            
            execution_arn = response['executionArn']
            execution_arns.append(execution_arn)
            
            logger.info(f"Successfully started Step Function execution: {execution_arn}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully triggered Step Functions',
                'executions': execution_arns
            })
        }
        
    except ValueError as e:
        # Log the error, but return a successful status (200) to S3 to halt gracefully.
        logger.error(f"Validation error: {str(e)}. Pipeline execution halted gracefully.")
        return {
            'statusCode': 200,
            'body': json.dumps({'message': f'Validation failed, pipeline halted: {str(e)}'})
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        raise # Still raise for true system errors