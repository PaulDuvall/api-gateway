#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Test for CloudFormation template validation and parameter usage.

This module tests the CloudFormation template to ensure that:
1. API Key and Usage Plan names are properly parameterized
2. The template uses unique suffix strategy for resource naming
"""

import os
import unittest
import subprocess
from datetime import datetime

class TestCloudFormationTemplate(unittest.TestCase):
    """Tests for the CloudFormation template."""

    def setUp(self):
        """Set up test environment."""
        self.script_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        self.template_path = os.path.join(self.script_dir, 'template.yaml')
        
        # Read the template as text
        with open(self.template_path, 'r') as file:
            self.template_content = file.read()
            
        # Generate a unique identifier for testing
        self.unique_id = datetime.now().strftime("%Y%m%d%H%M%S")
        
    def test_template_exists(self):
        """Test that the CloudFormation template file exists."""
        self.assertTrue(os.path.isfile(self.template_path), 
                       f"CloudFormation template not found at {self.template_path}")
    
    def test_template_validation(self):
        """Test that the CloudFormation template is valid."""
        # Skip this test if running in CI environment without AWS credentials
        if os.environ.get('CI') == 'true' and not (os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION')):
            self.skipTest("Skipping CloudFormation validation in CI environment without AWS region")
            
        # Use environment variable for region if available
        region = os.environ.get('AWS_REGION') or os.environ.get('AWS_DEFAULT_REGION')
        region_arg = []
        if region:
            region_arg = ['--region', region]
            
        # Use AWS CLI to validate the template
        try:
            result = subprocess.run(
                ['aws', 'cloudformation', 'validate-template', 
                 '--template-body', f'file://{self.template_path}'] + region_arg,
                capture_output=True, text=True, check=True
            )
            # If validation succeeds, the test passes
            self.assertTrue(True)
        except subprocess.CalledProcessError as e:
            # If validation fails, the test fails with the error message
            self.fail(f"Template validation failed: {e.stderr}")
    
    def test_api_key_name_parameterized(self):
        """Test that the API Key name is parameterized."""
        # Check if ApiKeyName parameter exists
        self.assertIn('ApiKeyName:', self.template_content, 
                     "ApiKeyName parameter not found in template")
        
        # Check if the API Key resource uses the parameter
        api_key_section = self.template_content.split('HelloWorldApiKey:')[1].split('HelloWorldUsagePlan')[0]
        self.assertTrue('Name: !Sub ${ApiKeyName}' in api_key_section or 
                       'Name:' in api_key_section and '!Sub ${ApiKeyName}' in api_key_section,
                       "HelloWorldApiKey Name property does not use a parameter reference")
    
    def test_usage_plan_name_parameterized(self):
        """Test that the Usage Plan name is parameterized."""
        # Check if UsagePlanName parameter exists
        self.assertIn('UsagePlanName:', self.template_content, 
                     "UsagePlanName parameter not found in template")
        
        # Check if the Usage Plan resource uses the parameter
        usage_plan_section = self.template_content.split('HelloWorldUsagePlan:')[1].split('HelloWorldUsagePlanKey')[0]
        self.assertTrue('UsagePlanName: !Sub ${UsagePlanName}' in usage_plan_section or
                       'UsagePlanName:' in usage_plan_section and '!Sub ${UsagePlanName}' in usage_plan_section,
                       "HelloWorldUsagePlan UsagePlanName property does not use a parameter reference")
    
    def test_unique_suffix_strategy(self):
        """Test that the template supports a unique suffix strategy for resource names."""
        # Check if DeploymentTimestamp parameter exists
        self.assertIn('DeploymentTimestamp:', self.template_content, 
                     "DeploymentTimestamp parameter not found in template")
        
        # Check if ApiKeyName default value includes DeploymentTimestamp
        api_key_name_default = self.template_content.split('ApiKeyName:')[1].split('Description:')[0]
        self.assertIn('${DeploymentTimestamp}', api_key_name_default, 
                     "ApiKeyName default value does not include DeploymentTimestamp")
        
        # Check if UsagePlanName default value includes DeploymentTimestamp
        usage_plan_name_default = self.template_content.split('UsagePlanName:')[1].split('Description:')[0]
        self.assertIn('${DeploymentTimestamp}', usage_plan_name_default, 
                     "UsagePlanName default value does not include DeploymentTimestamp")
    
    def test_lambda_function_name_format(self):
        """Test that the Lambda function name format uses underscores instead of hyphens."""
        # Check if the Lambda function resource exists
        self.assertIn('HelloWorldFunction:', self.template_content,
                     "HelloWorldFunction resource not found in template")
        
        # Check if the Lambda function name uses underscores instead of hyphens
        lambda_function_section = self.template_content.split('HelloWorldFunction:')[1].split('HelloWorldApi:')[0]
        self.assertIn('FunctionName: !Sub "${LambdaFunctionName}_${StageName}_${DeploymentTimestamp}"', lambda_function_section,
                     "Lambda function name should use underscores instead of hyphens")
    
    def test_ssm_parameter_path(self):
        """Test that the SSM parameter has a proper path with leading slash."""
        # Check if the DeploymentTimestampParam resource exists
        self.assertIn('DeploymentTimestampParam:', self.template_content,
                     "DeploymentTimestampParam resource not found in template")
        
        # Check if the parameter name has a leading slash
        param_section = self.template_content.split('DeploymentTimestampParam:')[1].split('Outputs:')[0]
        self.assertIn('Name: "/helloworld/', param_section,
                     "SSM Parameter name should have a proper path with leading slash")


if __name__ == '__main__':
    unittest.main()
