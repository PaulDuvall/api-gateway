#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unit tests for the PDF hash service.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock, mock_open
import hashlib
import io

# Add the parent directory to the Python path to import the Lambda function
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Clear any existing mocks of pdf_hash_service
if 'pdf_hash_service' in sys.modules:
    del sys.modules['pdf_hash_service']

# Mock the reportlab module before importing pdf_hash_service
sys.modules['reportlab'] = MagicMock()
sys.modules['reportlab.pdfgen'] = MagicMock()
sys.modules['reportlab.pdfgen.canvas'] = MagicMock()
sys.modules['reportlab.lib'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'] = MagicMock()
sys.modules['reportlab.lib.pagesizes'].letter = (612, 792)  # Standard letter size in points

# Now import the module
import pdf_hash_service


class TestPdfHashService(unittest.TestCase):
    """Test cases for the PDF hash service."""

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
        
        # Reset module variables that depend on environment variables
        pdf_hash_service.S3_BUCKET_NAME = self.test_bucket_name

    def tearDown(self):
        """Clean up test fixtures after each test."""
        self.env_patcher.stop()

    def test_generate_pdf(self):
        """Test PDF generation functionality."""
        # Mock the BytesIO and Canvas classes
        mock_buffer = MagicMock(spec=io.BytesIO)
        mock_buffer.getvalue.return_value = b'test pdf content'
        
        with patch('io.BytesIO', return_value=mock_buffer), \
             patch('pdf_hash_service.canvas.Canvas') as mock_canvas:
            
            mock_instance = MagicMock()
            mock_canvas.return_value = mock_instance
            
            # Call the function
            pdf_data = pdf_hash_service.generate_pdf("Test Title", "Test Content")
            
            # Verify the PDF was created with the right content
            self.assertEqual(pdf_data, b'test pdf content')
            mock_instance.drawString.assert_called()
            mock_instance.save.assert_called_once()

    def test_create_presigned_url(self):
        """Test creation of pre-signed URL for S3 upload."""
        with patch('boto3.client') as mock_boto3_client:
            mock_s3_client = MagicMock()
            mock_boto3_client.return_value = mock_s3_client
            mock_s3_client.generate_presigned_url.return_value = f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test'
            
            # Call the function
            presigned_url = pdf_hash_service.create_presigned_url('test-key', 3600)
            
            # Verify the URL was created correctly
            self.assertEqual(presigned_url, f'https://{self.test_bucket_name}.s3.amazonaws.com/test-key?AWSAccessKeyId=test')
            mock_s3_client.generate_presigned_url.assert_called_with(
                'put_object',
                Params={'Bucket': self.test_bucket_name, 'Key': 'test-key'},
                ExpiresIn=3600
            )

    def test_upload_to_presigned_url(self):
        """Test uploading to a pre-signed URL."""
        with patch('requests.put') as mock_put:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_put.return_value = mock_response
            
            # Call the function
            result = pdf_hash_service.upload_to_presigned_url(b'test data', 'https://test-url.com')
            
            # Verify the upload was successful
            self.assertTrue(result)
            mock_put.assert_called_with(
                'https://test-url.com',
                data=b'test data',
                headers={'Content-Type': 'application/pdf'}
            )

    def test_download_from_url(self):
        """Test downloading from a URL."""
        with patch('requests.get') as mock_get:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.content = b'test pdf content'
            mock_get.return_value = mock_response
            
            # Call the function
            content = pdf_hash_service.download_from_url('https://test-url.com')
            
            # Verify the download was successful
            self.assertEqual(content, b'test pdf content')
            mock_get.assert_called_with('https://test-url.com')

    def test_compute_sha256(self):
        """Test SHA-256 hash computation."""
        test_data = b'test data'
        expected_hash = hashlib.sha256(test_data).hexdigest()
        
        # Call the function
        result = pdf_hash_service.compute_sha256(test_data)
        
        # Verify the hash was computed correctly
        self.assertEqual(result, expected_hash)


if __name__ == '__main__':
    unittest.main()
