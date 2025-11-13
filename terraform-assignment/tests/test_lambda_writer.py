import unittest
import json
import os
from unittest.mock import patch
from botocore.exceptions import ClientError
# FIX: Import as a package, using the full path.
import lambda_writer.index as writer_index

class TestLambdaWriter(unittest.TestCase):
    
    @patch.dict(os.environ, {'TABLE_NAME': 'test-table'})
    @patch('lambda_writer.index.table') # FIX: Patch the full package name
    def test_successful_write(self, mock_table):
        """Test successful DynamoDB write"""
        # Arrange
        mock_table.put_item.return_value = {}
        
        event = {
            'bucket': 'test-bucket',
            'key': 'test-file.txt',
            'timestamp': '2025-01-01T00:00:00',
            'event_time': '2025-01-01T00:00:00Z'
        }
        
        # Act
        result = writer_index.handler(event, None)
        
        # Assert
        self.assertEqual(result['statusCode'], 200)
        self.assertEqual(result['filename'], 'test-file.txt')
        mock_table.put_item.assert_called_once()
    
    @patch.dict(os.environ, {'TABLE_NAME': 'test-table'})
    @patch('lambda_writer.index.table') # FIX: Patch the full package name
    def test_duplicate_entry(self, mock_table):
        """Test handling of duplicate entries"""
        # Arrange
        error_response = {'Error': {'Code': 'ConditionalCheckFailedException'}}
        mock_table.put_item.side_effect = ClientError(error_response, 'PutItem')
        
        event = {
            'bucket': 'test-bucket',
            'key': 'test-file.txt',
            'timestamp': '2025-01-01T00:00:00'
        }
        
        # Act
        result = writer_index.handler(event, None)
        
        # Assert
        self.assertEqual(result['statusCode'], 409)
        self.assertIn('Duplicate', result['message'])
    
    def test_invalid_filename_empty(self):
        """Test that empty filenames are rejected"""
        invalid_filename = ''
        with self.assertRaises(ValueError):
            writer_index.validate_filename(invalid_filename)
    
    def test_invalid_filename_path_traversal(self):
        """Test that path traversal is rejected"""
        invalid_filename = '../../../etc/passwd'
        with self.assertRaises(ValueError):
            writer_index.validate_filename(invalid_filename)
    
    def test_valid_filename(self):
        """Test that valid filenames pass validation"""
        valid_filename = 'folder/valid-file.txt'
        result = writer_index.validate_filename(valid_filename)
        self.assertTrue(result)

if __name__ == '__main__':
    unittest.main()