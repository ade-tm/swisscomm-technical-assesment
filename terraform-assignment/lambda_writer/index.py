import json
import boto3
import os
import logging
from datetime import datetime, UTC
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# FIX: Initialize Boto3 clients here as None to prevent crash on module import
dynamodb = None
table = None

def get_dynamodb_table():
    """Initializes global Boto3 clients and table lazily on first call."""
    global dynamodb
    global table
    
    # Only initialize if it hasn't been done yet
    if table is not None:
        return table

    # Initialization that relies on os.environ
    endpoint_url = os.environ.get('AWS_ENDPOINT_URL')
    dynamodb = boto3.resource('dynamodb', endpoint_url=endpoint_url)
    
    # This line now safely runs inside the function call, where the environment is mocked.
    # We use os.environ[] assuming the test/Lambda environment has set the variable.
    table = dynamodb.Table(os.environ['TABLE_NAME']) 
    return table

def validate_filename(filename):
    """
    Validate filename before writing to DynamoDB
    """
    if not filename or not filename.strip():
        raise ValueError("Filename cannot be empty")
    if len(filename) > 1024:
        raise ValueError(f"Filename too long: {len(filename)} characters (max: 1024)")
    if '..' in filename or filename.startswith('/'):
        raise ValueError(f"Invalid filename (path traversal attempt): {filename}")
    if '\x00' in filename:
        raise ValueError(f"Filename contains null bytes: {filename}")
    
    logger.info(f"Filename validation passed: {filename}")
    return True

def handler(event, context):
    """
    Lambda handler to write file metadata to DynamoDB
    """
    try:
        # Get the initialized table resource. This is safe because the environment
        # is guaranteed to be set when handler runs.
        ddb_table = get_dynamodb_table()
        
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Extract data from event
        filename = event['key']
        timestamp = event.get('timestamp', datetime.now(UTC).isoformat())
        bucket = event['bucket']
        event_time = event.get('event_time', timestamp)
        
        # Validate inputs
        validate_filename(filename)
        
        # Prepare DynamoDB item
        item = {
            'Filename': filename,
            'UploadTimestamp': timestamp,
            'Bucket': bucket,
            'EventTime': event_time
        }
        
        logger.info(f"Writing to DynamoDB: {item}")
        
        # Write to DynamoDB with conditional expression
        try:
            ddb_table.put_item( # Use the local table variable
                Item=item,
                ConditionExpression='attribute_not_exists(Filename) AND attribute_not_exists(UploadTimestamp)'
            )
            
            logger.info(f"Successfully wrote to DynamoDB: {filename}")
            
            return {
                'statusCode': 200,
                'filename': filename,
                'timestamp': timestamp,
                'bucket': bucket,
                'message': 'Successfully written to DynamoDB'
            }
            
        except ClientError as e:
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                logger.warning(f"Duplicate entry attempted: {filename} at {timestamp}")
                return {
                    'statusCode': 409,
                    'filename': filename,
                    'timestamp': timestamp,
                    'message': 'Duplicate entry - item already exists'
                }
            else:
                raise
        
    except ValueError as e:
        logger.error(f"Validation error: {str(e)}")
        raise
    except ClientError as e:
        logger.error(f"DynamoDB client error: {str(e)}", exc_info=True)
        raise
    except Exception as e:
        logger.error(f"Unexpected error writing to DynamoDB: {str(e)}", exc_info=True)
        raise