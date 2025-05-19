#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unit tests for the PDF hash Lambda function.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the parent directory to the Python path to import the Lambda function
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Clear any existing mocks of pdf_hash_service
if 'pdf_hash_service' in sys.modules:
    del sys.modules['pdf_hash_service']

# Mock the reportlab module before importing pdf_hash_lambda
sys.modules['reportlab'] = MagicMock()
sys.modules['reportlab.pdfgen'] = MagicMock()
sys.modules['reportlab.pdfgen.canvas'] = MagicMock()
sys.modules['reportlab.lib'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'].letter = (612, 792)  # Standard letter size in points

# Now import the module
import pdf_hash_lambda

# Replace the mocked functions with our test functions
pdf_hash_lambda.download_from_url = MagicMock(return_value=b'test pdf content')
pdf_hash_lambda.compute_sha256 = MagicMock(return_value='test-hash-value')


class TestPdfHashLambda(unittest.TestCase):
    """Test cases for the PDF hash Lambda function."""

    def setUp(self):
        """Set up test fixtures before each test."""
        # Mock environment variables
        self.test_bucket_name = 'helloworld-pdf-test-123456789012-us-east-1-20250404'
        self.env_patcher = patch.dict('os.environ', {
            'ENVIRONMENT': 'test',
            'S3_BUCKET_NAME': self.test_bucket_name,
            'S3_PRESIGNED_URL_EXPIRATION': '3600'
        })
        self.env_patcher.start()
        
        # Reset the mocks before each test
        pdf_hash_lambda.download_from_url.reset_mock()
        pdf_hash_lambda.compute_sha256.reset_mock()

    def tearDown(self):
        """Clean up test fixtures after each test."""
        self.env_patcher.stop()

    def test_lambda_handler_post_with_url(self):
        """Test lambda_handler with a POST request containing a pre-signed URL."""
        # Create a test event with a pre-signed URL in the body
        event = {
            'httpMethod': 'POST',
            'path': '/pdf-hash',
            'headers': {
                'x-api-key': 'test-api-key'
            },
            'body': json.dumps({
                'url': f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            })
        }
        context = MagicMock()

        # Call the lambda handler
        response = pdf_hash_lambda.lambda_handler(event, context)

        # Assert the response structure
        self.assertEqual(response['statusCode'], 200)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertIn('hash', body)
        self.assertEqual(body['hash'], 'test-hash-value')
        self.assertEqual(body['status'], 'success')
        
        # Verify the functions were called with correct parameters
        pdf_hash_lambda.download_from_url.assert_called_with(
            f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
        )
        pdf_hash_lambda.compute_sha256.assert_called_with(b'test pdf content')

    def test_lambda_handler_error_handling(self):
        """Test lambda_handler error handling."""
        # Mock the download to raise an exception for this test only
        pdf_hash_lambda.download_from_url.side_effect = Exception('Test error')
        
        # Create a test event with a pre-signed URL in the body
        event = {
            'httpMethod': 'POST',
            'path': '/pdf-hash',
            'headers': {
                'x-api-key': 'test-api-key'
            },
            'body': json.dumps({
                'url': f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            })
        }
        context = MagicMock()

        # Call the lambda handler
        response = pdf_hash_lambda.lambda_handler(event, context)

        # Assert the response structure for errors
        self.assertEqual(response['statusCode'], 500)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertEqual(body['status'], 'error')
        self.assertIn('error', body)
        # In test environment, we should see the actual error message
        self.assertIn('message', body)
        self.assertEqual(body['message'], 'Test error')
        
        # Reset the side_effect after this test
        pdf_hash_lambda.download_from_url.side_effect = None

    def test_lambda_handler_missing_url(self):
        """Test lambda_handler with missing URL parameter."""
        # Create a test event with no URL in the body
        event = {
            'httpMethod': 'POST',
            'path': '/pdf-hash',
            'headers': {
                'x-api-key': 'test-api-key'
            },
            'body': json.dumps({
                'some_other_param': 'value'
            })
        }
        context = MagicMock()

        # Call the lambda handler
        response = pdf_hash_lambda.lambda_handler(event, context)

        # Assert the response structure for errors
        self.assertEqual(response['statusCode'], 400)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertEqual(body['status'], 'error')
        self.assertIn('error', body)
        self.assertEqual(body['error'], 'Missing required parameter: url')


if __name__ == '__main__':
    unittest.main()
