#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Unit tests for the Hello World Lambda function.

Related User Stories:
- US-301: API Key Management
- US-303: Automated API Testing with Authentication
"""

import json
import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Add the parent directory to the Python path to import the Lambda function
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import lambda_function


class TestLambdaFunction(unittest.TestCase):
    """Test cases for the Hello World Lambda function."""

    def setUp(self):
        """Set up test fixtures before each test."""
        # Mock environment variables
        self.env_patcher = patch.dict('os.environ', {'ENVIRONMENT': 'test'})
        self.env_patcher.start()
        
        # Ensure the lambda_function module uses our patched environment
        # This is necessary because the module might have already imported os.environ
        lambda_function.ENVIRONMENT = 'test'

    def tearDown(self):
        """Clean up test fixtures after each test."""
        self.env_patcher.stop()

    def test_lambda_handler_default(self):
        """Test lambda_handler with default parameters."""
        # Create a test event with no query parameters
        event = {
            'httpMethod': 'GET',
            'path': '/hello',
            'headers': {
                'x-api-key': 'test-api-key'
            },
            'queryStringParameters': None
        }
        context = MagicMock()

        # Call the lambda handler
        response = lambda_function.lambda_handler(event, context)

        # Assert the response structure
        self.assertEqual(response['statusCode'], 200)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertIn('message', body)
        self.assertIn('Hello, World', body['message'])
        # Environment should be included in test mode
        self.assertIn('Environment: test', body['message'])

    def test_lambda_handler_with_name(self):
        """Test lambda_handler with a name parameter."""
        # Create a test event with a name query parameter
        event = {
            'httpMethod': 'GET',
            'path': '/hello',
            'headers': {
                'x-api-key': 'test-api-key'
            },
            'queryStringParameters': {
                'name': 'TestUser'
            }
        }
        context = MagicMock()

        # Call the lambda handler
        response = lambda_function.lambda_handler(event, context)

        # Assert the response structure
        self.assertEqual(response['statusCode'], 200)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertIn('message', body)
        self.assertIn('Hello, TestUser', body['message'])

    def test_lambda_handler_error_handling(self):
        """Test lambda_handler error handling."""
        # Create a test event that will cause an exception
        event = 'invalid_event'  # This will cause a TypeError
        context = MagicMock()

        # Call the lambda handler
        response = lambda_function.lambda_handler(event, context)

        # Assert the response structure for errors
        self.assertEqual(response['statusCode'], 500)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertEqual(body['status'], 'error')
        self.assertIn('error', body)
        # In test environment, we should see the actual error message
        self.assertIn('message', body)
        self.assertNotEqual(body['message'], 'An unexpected error occurred')
        
    def test_lambda_handler_with_parameterized_api_key(self):
        """Test lambda_handler with a parameterized API key."""
        # Create a test event with a parameterized API key
        timestamp = lambda_function.datetime.now().strftime('%Y%m%d%H%M%S')
        parameterized_key = f"HelloWorldApiKey-{timestamp}"
        
        event = {
            'httpMethod': 'GET',
            'path': '/hello',
            'headers': {
                'x-api-key': parameterized_key
            },
            'queryStringParameters': {
                'name': 'APIKeyUser'
            }
        }
        context = MagicMock()
        
        # Mock the logging function to capture what's being logged
        with patch.object(lambda_function.logger, 'info') as mock_logger:
            # Call the lambda handler
            response = lambda_function.lambda_handler(event, context)
            
            # Verify that the API key was logged in the event
            event_logged = False
            for call in mock_logger.call_args_list:
                args, _ = call
                if 'Received event' in args[0] and parameterized_key in args[1]:
                    event_logged = True
                    break
            
            self.assertTrue(event_logged, "The parameterized API key should be logged with the event")
        
        # Assert the response structure
        self.assertEqual(response['statusCode'], 200)
        self.assertIn('body', response)
        
        # Parse the body and check content
        body = json.loads(response['body'])
        self.assertIn('message', body)
        self.assertIn('Hello, APIKeyUser', body['message'])

# Adding a comment to trigger GitHub Actions workflow - April 4, 2025

if __name__ == '__main__':
    unittest.main()
