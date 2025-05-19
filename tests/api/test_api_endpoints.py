#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
End-to-end API tests for the Hello World API.

Related User Stories:
- US-301: API Key Management
- US-303: Automated API Testing with Authentication
"""

import json
import os
import sys
import unittest
import requests
from unittest.mock import patch


class TestApiEndpoints(unittest.TestCase):
    """End-to-end tests for the Hello World API endpoints."""

    @classmethod
    def setUpClass(cls):
        """Set up test fixtures before running tests."""
        # Get API endpoint and key from environment or use defaults for local testing
        cls.api_endpoint = os.environ.get(
            'API_ENDPOINT',
            'https://example.execute-api.us-east-1.amazonaws.com/prod/hello'
        )
        cls.api_key = os.environ.get('API_KEY', 'test-api-key')
        
        # Check if we're running in CI/CD environment
        cls.is_ci = os.environ.get('CI', 'false').lower() == 'true'
        
        # Check if we have a valid API endpoint (not the example one)
        cls.has_valid_endpoint = 'example.execute-api' not in cls.api_endpoint

    def setUp(self):
        """Set up test fixtures before each test."""
        # Skip tests if we don't have a valid API endpoint or key
        if not self.has_valid_endpoint or self.api_key == 'test-api-key':
            self.skipTest("Skipping API tests: No valid API endpoint or key available")

    def test_get_hello_world(self):
        """Test the basic GET /hello endpoint."""
        # Make request to the API
        headers = {
            'x-api-key': self.api_key
        }
        response = requests.get(self.api_endpoint, headers=headers)
        
        # Assert response status and content
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('message', data)
        self.assertIn('Hello, World', data['message'])

    def test_get_hello_with_name(self):
        """Test the GET /hello endpoint with name parameter."""
        # Make request to the API with query parameter
        headers = {
            'x-api-key': self.api_key
        }
        response = requests.get(
            f"{self.api_endpoint}?name=TestUser",
            headers=headers
        )
        
        # Assert response status and content
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('message', data)
        self.assertIn('Hello, TestUser', data['message'])

    def test_missing_api_key(self):
        """Test the API behavior when API key is missing."""
        # Make request without API key
        response = requests.get(self.api_endpoint)
        
        # Assert response status is 403 Forbidden
        self.assertEqual(response.status_code, 403)

    def test_invalid_api_key(self):
        """Test the API behavior with invalid API key."""
        # Make request with invalid API key
        headers = {
            'x-api-key': 'invalid-api-key-12345'
        }
        response = requests.get(self.api_endpoint, headers=headers)
        
        # Assert response status is 403 Forbidden
        self.assertEqual(response.status_code, 403)


if __name__ == '__main__':
    unittest.main()
