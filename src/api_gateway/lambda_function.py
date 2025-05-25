#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Lambda function for the Hello World API.

This module handles API Gateway requests and returns formatted responses.
"""

import json
import logging
import os
import traceback
from datetime import datetime

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')


def lambda_handler(event, context):
    """
Lambda function handler for Hello World API.

This function processes API Gateway requests and returns a formatted response.

Args:
    event (dict): API Gateway Lambda Proxy Input Format
    context (object): Lambda Context runtime methods and attributes

Returns:
    dict: API Gateway Lambda Proxy Output Format
    """
    try:
        logger.info("Received event: %s", json.dumps(event))
        
        # Log all event keys for debugging
        logger.info("Event keys: %s", list(event.keys()))
        
        # Determine HTTP method
        http_method = event.get('httpMethod', 'GET')
        logger.info("HTTP Method: %s", http_method)
        
        # Get name from query params (GET) or body (POST)
        name = 'World'
        if http_method == 'POST' and event.get('body'):
            try:
                logger.info("Processing POST request with body: %s", event.get('body'))
                body = json.loads(event.get('body', '{}'))
                name = body.get('name', 'World')
                logger.info("Extracted name from POST body: %s", name)
            except json.JSONDecodeError as json_err:
                logger.warning("Could not parse request body as JSON: %s", str(json_err))
        elif http_method == 'GET':
            logger.info("Processing GET request")
            logger.info("Query string parameters: %s", event.get('queryStringParameters'))
            if event.get('queryStringParameters'):
                name = event['queryStringParameters'].get('name', 'World')
                logger.info("Extracted name from query parameters: %s", name)
        
        # Create response message
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        message = f"Hello, {name}! The time is {current_time}. Deployed with secure OIDC authentication and enhanced IAM permissions."
        logger.info("Created message: %s", message)
        
        # Add environment information if not production
        if ENVIRONMENT != 'prod':
            message += f" (Environment: {ENVIRONMENT})"
        
        # Construct the response object
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, POST",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({
                "message": message,
                "status": "success",
                "timestamp": datetime.now().isoformat(),
                "version": "1.1.0",
                "environment": ENVIRONMENT
            })
        }
        
        logger.info("Returning response: %s", json.dumps(response))
        return response
            
    except Exception as e:
        # Log the full exception with traceback
        logger.error("Error processing request: %s", str(e))
        logger.error(traceback.format_exc())
        
        # Return a proper error response
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "error": "Internal server error",
                "message": str(e) if ENVIRONMENT != 'prod' else "An unexpected error occurred",
                "status": "error"
            })
        }


if __name__ == "__main__":
    # Test the function locally
    test_event = {
        "httpMethod": "GET",
        "queryStringParameters": {
            "name": "Local Test"
        }
    }
    print(json.dumps(lambda_handler(test_event, None), indent=2))

# Updated on 2025-04-04: Fixed CloudFormation deployment issues and improved stack handling
# Added handling for ROLLBACK_FAILED state in GitHub Actions workflow
# Enhanced stack deletion handling for stuck resources
# Added specific handling for DELETE_FAILED state with new stack name
# Improved Lambda function with better error handling while maintaining test compatibility
# Fixed API Gateway integration issues with proper event handling
