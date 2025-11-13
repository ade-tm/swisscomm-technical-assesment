import unittest
import os
from unittest.mock import patch
from botocore.exceptions import ClientError
# FIX: Import as a package, using the full path.
import lambda_security_monitor.index as monitor_index

# CRITICAL FIX: Patch the environment to define AWS_REGION before Boto3 clients initialize 
@patch.dict(os.environ, {
    'AWS_REGION': 'eu-central-1', 
    'SNS_TOPIC_ARN': 'arn:aws:sns:eu-central-1:123456789012:test' # Required for send_alert test
})
class TestSecurityMonitor(unittest.TestCase):
    
    @patch('lambda_security_monitor.index.s3')
    def test_s3_compliant_kms_bucket(self, mock_s3):
        """Test that a KMS-encrypted bucket passes the check"""
        # Arrange
        mock_s3.list_buckets.return_value = {
            'Buckets': [{'Name': 'compliant-bucket'}]
        }
        mock_s3.get_bucket_encryption.return_value = {
            'ServerSideEncryptionConfiguration': {
                'Rules': [{
                    'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'aws:kms'}
                }]
            }
        }
        
        # Act
        issues = monitor_index.check_s3_encryption()
        
        # Assert
        self.assertEqual(len(issues), 0)
    
    @patch('lambda_security_monitor.index.s3')
    def test_s3_non_compliant_aes256_bucket(self, mock_s3):
        """Test that a default (AES256) bucket is flagged"""
        # Arrange
        mock_s3.list_buckets.return_value = {
            'Buckets': [{'Name': 'non-compliant-bucket'}]
        }
        mock_s3.get_bucket_encryption.return_value = {
            'ServerSideEncryptionConfiguration': {
                'Rules': [{
                    'ApplyServerSideEncryptionByDefault': {'SSEAlgorithm': 'AES256'}
                }]
            }
        }
        
        # Act
        issues = monitor_index.check_s3_encryption()
        
        # Assert
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]['name'], 'non-compliant-bucket')
        self.assertIn('AES256', issues[0]['reason'])

    @patch('lambda_security_monitor.index.s3')
    def test_s3_truly_unencrypted_bucket(self, mock_s3):
        """Test that a (legacy) bucket with no encryption is flagged"""
        # Arrange
        mock_s3.list_buckets.return_value = {
            'Buckets': [{'Name': 'legacy-unencrypted-bucket'}]
        }
        error_response = {'Error': {'Code': 'ServerSideEncryptionConfigurationNotFoundError'}}
        mock_s3.get_bucket_encryption.side_effect = ClientError(error_response, 'GetBucketEncryption')
        
        # Act
        issues = monitor_index.check_s3_encryption()
        
        # Assert
        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]['name'], 'legacy-unencrypted-bucket')
        self.assertIn('no encryption', issues[0]['reason'])
    
    @patch('lambda_security_monitor.index.dynamodb')
    def test_check_dynamodb_encrypted_table(self, mock_dynamodb):
        """Test detection of encrypted DynamoDB tables"""
        # Arrange
        mock_dynamodb.list_tables.return_value = {
            'TableNames': ['encrypted-table']
        }
        mock_dynamodb.describe_table.return_value = {
            'Table': {
                'SSEDescription': {'Status': 'ENABLED'}
            }
        }
        
        # Act
        unencrypted = monitor_index.check_dynamodb_encryption()
        
        # Assert
        self.assertEqual(len(unencrypted), 0)
    
    @patch('lambda_security_monitor.index.dynamodb')
    def test_check_dynamodb_unencrypted_table(self, mock_dynamodb):
        """Test detection of unencrypted DynamoDB tables"""
        # Arrange
        mock_dynamodb.list_tables.return_value = {
            'TableNames': ['unencrypted-table']
        }
        mock_dynamodb.describe_table.return_value = {
            'Table': {}  # No SSEDescription means not encrypted
        }
        
        # Act
        unencrypted = monitor_index.check_dynamodb_encryption()
        
        # Assert
        self.assertEqual(len(unencrypted), 1)
        self.assertIn('unencrypted-table', unencrypted)
    
    @patch('lambda_security_monitor.index.sns')
    def test_send_alert(self, mock_sns):
        """Test sending SNS alerts"""
        # Arrange
        mock_sns.publish.return_value = {'MessageId': '12345'}
        issues = ['S3 Bucket test-bucket is not encrypted']
        
        # Act
        monitor_index.send_alert(issues)
        
        # Assert
        mock_sns.publish.assert_called_once()
        call_args = mock_sns.publish.call_args
        self.assertIn('Hi team', call_args[1]['Message'])
        self.assertIn('test-bucket', call_args[1]['Message'])
        self.assertIn('Security Bot', call_args[1]['Message'])

if __name__ == '__main__':
    unittest.main()