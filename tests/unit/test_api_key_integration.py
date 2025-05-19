#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Integration tests for API Key parameterization in CloudFormation and Lambda function.

Related User Stories:
- US-301: API Key Management
- US-303: Automated API Testing with Authentication
"""

import json
import os
import sys
import unittest
import re
from datetime import datetime
from unittest.mock import patch, MagicMock

# Add the parent directory to the Python path to import the Lambda function
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
import lambda_function


class TestApiKeyIntegration(unittest.TestCase):
    """Test cases for API Key parameterization integration."""

    def setUp(self):
        """Set up test fixtures before each test."""
        # Path to the CloudFormation template
        self.template_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
            'template.yaml'
        )
        
        # Read the CloudFormation template as text
        with open(self.template_path, 'r') as file:
            self.template_content = file.read()
        
        # Mock environment variables
        self.env_patcher = patch.dict('os.environ', {'ENVIRONMENT': 'test'})
        self.env_patcher.start()
        
        # Ensure the lambda_function module uses our patched environment
        lambda_function.ENVIRONMENT = 'test'

    def tearDown(self):
        """Clean up test fixtures after each test."""
        self.env_patcher.stop()

    def test_api_key_parameter_integration(self):
        """Test that the parameterized API key from CloudFormation works with Lambda."""
        # Verify that the API Key parameter exists in the CloudFormation template
        api_key_param_pattern = r'ApiKeyName:\s*\n\s*Type:\s*String'
        api_key_param_match = re.search(api_key_param_pattern, self.template_content)
        
        self.assertIsNotNone(api_key_param_match, "ApiKeyName parameter not found in template")
        
        # Check that the default value includes DeploymentTimestamp
        default_pattern = r'Default:\s*"([^"]+)"'
        default_match = re.search(default_pattern, self.template_content[api_key_param_match.end():])
        self.assertIsNotNone(default_match, "Default value for ApiKeyName not found")
        
        api_key_default = default_match.group(1)
        self.assertIn('${DeploymentTimestamp}', api_key_default, 
                      "ApiKeyName parameter should include DeploymentTimestamp for uniqueness")
        
        # Extract the base name from the default value (remove the timestamp part)
        base_name = api_key_default.split('${')[0].strip('-')
        
        # Create a simulated API key with current timestamp
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        parameterized_key = f"{base_name}-{timestamp}"
        
        # Create a test event with the parameterized API key
        event = {
            'httpMethod': 'GET',
            'path': '/hello',
            'headers': {
                'x-api-key': parameterized_key
            },
            'queryStringParameters': {
                'name': 'IntegrationTest'
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
        self.assertIn('Hello, IntegrationTest', body['message'])
        
        # Verify that the API Key resource in CloudFormation uses the parameter
        api_key_resource_pattern = r'HelloWorldApiKey:\s*\n\s*Type:\s*AWS::ApiGateway::ApiKey'
        api_key_resource_match = re.search(api_key_resource_pattern, self.template_content, re.DOTALL)
        self.assertIsNotNone(api_key_resource_match, 
                             "HelloWorldApiKey resource not found in template")
        
        # Check that the API Key Name property uses the ApiKeyName parameter
        name_ref_pattern = r'Name:\s*!Sub\s*\$\{ApiKeyName\}'
        name_ref_match = re.search(name_ref_pattern, 
                                  self.template_content[api_key_resource_match.end():api_key_resource_match.end() + 200], 
                                  re.DOTALL)
        self.assertIsNotNone(name_ref_match, 
                             "HelloWorldApiKey resource should reference ApiKeyName parameter")
        
        # Verify that the Usage Plan resource in CloudFormation uses the parameter
        usage_plan_resource_pattern = r'HelloWorldUsagePlan:\s*\n\s*Type:\s*AWS::ApiGateway::UsagePlan'
        usage_plan_resource_match = re.search(usage_plan_resource_pattern, self.template_content, re.DOTALL)
        self.assertIsNotNone(usage_plan_resource_match, 
                             "HelloWorldUsagePlan resource not found in template")
        
        # Check that the Usage Plan Name property uses the UsagePlanName parameter
        usage_plan_name_pattern = r'UsagePlanName:\s*!Sub\s*\$\{UsagePlanName\}'
        usage_plan_name_match = re.search(usage_plan_name_pattern, 
                                         self.template_content[usage_plan_resource_match.end():usage_plan_resource_match.end() + 200], 
                                         re.DOTALL)
        self.assertIsNotNone(usage_plan_name_match, 
                             "HelloWorldUsagePlan resource should reference UsagePlanName parameter")


if __name__ == '__main__':
    unittest.main()
