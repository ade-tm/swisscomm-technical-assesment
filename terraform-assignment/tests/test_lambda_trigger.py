import unittest
import json
import os
from unittest.mock import patch
from datetime import datetime
# FIX: Import as a package, using the full path.
import lambda_trigger.index as trigger_index

# CRITICAL FIXES APPLIED:
@patch.dict(os.environ, {
    # FIX: Set AWS_REGION to prevent Boto3 init failure during pytest collection
    'AWS_REGION': 'eu-central-1', 
    'STATE_MACHINE_ARN': 'arn:aws:states:eu-central-1:123456789012:stateMachine:test'
})
# PATCHING AT CLASS LEVEL: This passes an extra argument (mock_stepfunctions) to ALL methods
@patch('lambda_trigger.index.stepfunctions') 
class TestLambdaTrigger(unittest.TestCase):
    
    # This method takes the mock and is already correct.
    def test_successful_trigger(self, mock_stepfunctions):
        """Test successful Step Function trigger"""
        # Arrange
        mock_stepfunctions.start_execution.return_value = {
            'executionArn': 'arn:aws:states:eu-central-1:123456789012:execution:test:123'
        }
        
        event = {
            'Records': [{
                's3': {
                    'bucket': {'name': 'test-bucket'},
                    'object': {'key': 'test-file.txt'}
                },
                'eventTime': '2025-01-01T00:00:00Z'
            }]
        }
        
        # Act
        result = trigger_index.handler(event, None)
        
        # Assert
        self.assertEqual(result['statusCode'], 200)
        mock_stepfunctions.start_execution.assert_called_once()
    
    # FIX: Must accept the mock argument
    def test_invalid_key_null_bytes(self, mock_stepfunctions):
        """Test that null bytes are rejected"""
        invalid_key = 'test\x00file.txt'
        with self.assertRaises(ValueError):
            trigger_index.validate_s3_key(invalid_key)
    
    # FIX: Must accept the mock argument
    def test_invalid_key_path_traversal(self, mock_stepfunctions):
        """Test that path traversal is rejected"""
        invalid_key = '../../../etc/passwd'
        with self.assertRaises(ValueError):
            trigger_index.validate_s3_key(invalid_key)
    
    # FIX: Must accept the mock argument
    def test_invalid_key_too_long(self, mock_stepfunctions):
        """Test that overly long keys are rejected"""
        invalid_key = 'a' * 1025
        with self.assertRaises(ValueError):
            trigger_index.validate_s3_key(invalid_key)
    
    # FIX: Must accept the mock argument
    def test_valid_key(self, mock_stepfunctions):
        """Test that valid keys pass validation"""
        valid_key = 'folder/subfolder/valid-file.txt'
        result = trigger_index.validate_s3_key(valid_key)
        self.assertTrue(result)

if __name__ == '__main__':
    unittest.main()