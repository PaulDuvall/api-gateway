#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Test the Lambda function naming strategy in the CloudFormation template.

Related User Stories:
- US-201: Infrastructure as Code
- US-202: Resource Naming Strategy
"""

import os
import re
import unittest
import yaml
from datetime import datetime


class TestFunctionNamingStrategy(unittest.TestCase):
    """Test class for verifying the Lambda function naming strategy."""

    def setUp(self):
        """Set up test fixtures."""
        self.template_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            "template.yaml"
        )
        with open(self.template_path, "r") as f:
            self.template_content = f.read()

    def test_function_name_parameterization(self):
        """Test that the Lambda function name is properly parameterized."""
        # Check if the template has a LambdaFunctionName parameter
        self.assertIn("LambdaFunctionName", self.template_content,
                      "Template should have a LambdaFunctionName parameter")

        # Parse the template to check the parameter definition
        # We need to handle intrinsic functions like !Sub, so we'll use regex
        # rather than parsing the YAML directly
        parameter_pattern = re.compile(
            r"LambdaFunctionName:\s*\n\s*Type:\s*String"
        )
        self.assertTrue(parameter_pattern.search(self.template_content),
                       "LambdaFunctionName should be defined as a String parameter")

        # Check that the Lambda function uses the !Sub intrinsic function with all components
        # Updated to use underscores instead of hyphens for AWS Lambda naming compatibility
        function_name_pattern = re.compile(
            r"FunctionName:\s*!Sub\s*['\"]\$\{LambdaFunctionName\}_\$\{StageName\}_\$\{DeploymentTimestamp\}['\"]")
        self.assertTrue(function_name_pattern.search(self.template_content),
                       "Lambda function name should use !Sub with LambdaFunctionName, StageName, and DeploymentTimestamp using underscores as separators")

    def test_function_name_uniqueness(self):
        """Test that the function naming strategy ensures uniqueness."""
        # This test will verify that our run.sh script sets a unique value for the timestamp parameter
        run_sh_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            "run.sh"
        )
        with open(run_sh_path, "r") as f:
            run_sh_content = f.read()

        # Check for timestamp-based naming in the deployment
        timestamp_pattern = re.compile(
            r"TIMESTAMP=\$\(date \+\"%Y%m%d%H%M%S\"\)"
        )
        self.assertTrue(timestamp_pattern.search(run_sh_content),
                       "run.sh should set TIMESTAMP with a date format for uniqueness")

        # Check that StageName parameter is passed to CloudFormation
        stage_pattern = re.compile(
            r"--parameters.*ParameterKey=StageName,ParameterValue=.*"
        )
        self.assertTrue(stage_pattern.search(run_sh_content),
                      "run.sh should pass StageName parameter to CloudFormation")
