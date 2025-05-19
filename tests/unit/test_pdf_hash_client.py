#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unit tests for the PDF hash client.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the parent directory to the Python path to import the client
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Clear any existing mocks of pdf_hash_service
if 'pdf_hash_service' in sys.modules:
    del sys.modules['pdf_hash_service']

# Mock the reportlab module before importing pdf_hash_client
sys.modules['reportlab'] = MagicMock()
sys.modules['reportlab.pdfgen'] = MagicMock()
sys.modules['reportlab.pdfgen.canvas'] = MagicMock()
sys.modules['reportlab.lib'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'].letter = (612, 792)  # Standard letter size in points

# Now import the module
import pdf_hash_client

# Replace the mocked functions with our test functions
pdf_hash_client.generate_pdf = MagicMock()
pdf_hash_client.create_presigned_url = MagicMock()
pdf_hash_client.upload_to_presigned_url = MagicMock()


class TestPdfHashClient(unittest.TestCase):
    """Test cases for the PDF hash client."""

    def setUp(self):
        """Set up test fixtures before each test."""
        # Mock environment variables
        self.test_bucket_name = 'helloworld-pdf-test-123456789012-us-east-1-20250404'
        self.test_api_endpoint = 'https://example.com/test/pdf-hash'
        self.test_api_key = 'test-api-key'
        
        self.env_patcher = patch.dict('os.environ', {
            'ENVIRONMENT': 'test',
            'API_ENDPOINT': self.test_api_endpoint,
            'API_KEY': self.test_api_key,
            'S3_BUCKET_NAME': self.test_bucket_name
        })
        self.env_patcher.start()
        
        # Reset module variables that depend on environment variables
        pdf_hash_client.ENVIRONMENT = 'test'
        pdf_hash_client.API_ENDPOINT = self.test_api_endpoint
        pdf_hash_client.API_KEY = self.test_api_key
        pdf_hash_client.S3_BUCKET_NAME = self.test_bucket_name
        
        # Reset the mocks before each test
        pdf_hash_client.generate_pdf.reset_mock()
        pdf_hash_client.create_presigned_url.reset_mock()
        pdf_hash_client.upload_to_presigned_url.reset_mock()
        
        # Clear any side effects
        pdf_hash_client.generate_pdf.side_effect = None
        pdf_hash_client.create_presigned_url.side_effect = None
        pdf_hash_client.upload_to_presigned_url.side_effect = None

    def tearDown(self):
        """Clean up test fixtures after each test."""
        self.env_patcher.stop()

    def test_generate_and_hash_pdf_workflow(self):
        """Test the complete PDF generation and hashing workflow."""
        # Mock the function calls
        pdf_hash_client.generate_pdf.return_value = b'test pdf content'
        pdf_hash_client.create_presigned_url.return_value = f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
        pdf_hash_client.upload_to_presigned_url.return_value = True
        
        with patch('pdf_hash_client.invoke_api') as mock_invoke_api:
            mock_invoke_api.return_value = {'hash': 'test-hash-value', 'status': 'success'}
            
            # Call the workflow function
            result = pdf_hash_client.generate_and_hash_pdf("Test Title", "Test Content")
            
            # Verify the result
            self.assertEqual(result, 'test-hash-value')
            
            # Verify each step was called with correct parameters
            pdf_hash_client.generate_pdf.assert_called_with("Test Title", "Test Content")
            pdf_hash_client.create_presigned_url.assert_called()
            pdf_hash_client.upload_to_presigned_url.assert_called_with(
                b'test pdf content', 
                f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            )
            mock_invoke_api.assert_called_with(
                self.test_api_endpoint, 
                self.test_api_key, 
                f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            )

    def test_invoke_api(self):
        """Test the API invocation function."""
        with patch('requests.post') as mock_post:
            # Mock the response
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json.return_value = {'hash': 'test-hash-value', 'status': 'success'}
            mock_post.return_value = mock_response
            
            # Call the function
            result = pdf_hash_client.invoke_api(
                self.test_api_endpoint,
                self.test_api_key,
                f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            )
            
            # Verify the result
            self.assertEqual(result, {'hash': 'test-hash-value', 'status': 'success'})
            
            # Verify the API was called with correct parameters
            mock_post.assert_called_with(
                self.test_api_endpoint,
                headers={'x-api-key': self.test_api_key, 'Content-Type': 'application/json'},
                json={'url': f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'}
            )

    def test_error_handling(self):
        """Test error handling in the workflow."""
        # Mock the generate_pdf function to succeed
        pdf_hash_client.generate_pdf.return_value = b'test pdf content'
        
        # Mock the create_presigned_url function to raise an exception
        pdf_hash_client.create_presigned_url.side_effect = Exception('Test error')
        
        # Call the workflow function and expect an exception
        with self.assertRaises(Exception) as context:
            pdf_hash_client.generate_and_hash_pdf("Test Title", "Test Content")
        
        # Verify the error message
        self.assertIn('Test error', str(context.exception))
        
        # Reset the side effect after this test
        pdf_hash_client.create_presigned_url.side_effect = None


if __name__ == '__main__':
    unittest.main()
