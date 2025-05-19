#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
PDF Hash Lambda Function for API Gateway integration.

This module provides a Lambda function that computes the SHA-256 hash of a PDF
retrieved from a pre-signed URL.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import json
import logging
import os
import traceback
from datetime import datetime

# Import the PDF hash service functions
from pdf_hash_service import download_from_url, compute_sha256

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')


def lambda_handler(event, context):
    """
    AWS Lambda function handler for PDF hash API.
    
    Args:
        event (dict): Input event to the Lambda function
        context (LambdaContext): Runtime information provided by AWS Lambda
        
    Returns:
        dict: API Gateway response containing status code, headers, and body
    """
    try:
        logger.info("Received event: %s", json.dumps(event))
        
        # Determine HTTP method
        http_method = event.get('httpMethod', 'GET')
        
        # Only accept POST requests
        if http_method != 'POST':
            return {
                "statusCode": 405,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({
                    "error": "Method not allowed",
                    "message": "Only POST requests are supported",
                    "status": "error"
                })
            }
        
        # Parse the request body
        body = {}
        if event.get('body'):
            try:
                body = json.loads(event.get('body'))
            except json.JSONDecodeError as e:
                return {
                    "statusCode": 400,
                    "headers": {
                        "Content-Type": "application/json",
                        "Access-Control-Allow-Origin": "*"
                    },
                    "body": json.dumps({
                        "error": "Invalid request body",
                        "message": str(e),
                        "status": "error"
                    })
                }
        
        # Check if the URL parameter is present
        if 'url' not in body:
            return {
                "statusCode": 400,
                "headers": {
                    "Content-Type": "application/json",
                    "Access-Control-Allow-Origin": "*"
                },
                "body": json.dumps({
                    "error": "Missing required parameter: url",
                    "status": "error"
                })
            }
        
        # Get the URL from the request body
        url = body['url']
        
        # Download the PDF from the URL
        pdf_data = download_from_url(url)
        
        # Compute the SHA-256 hash of the PDF
        pdf_hash = compute_sha256(pdf_data)
        
        # Construct the response object
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            "body": json.dumps({
                "hash": pdf_hash,
                "status": "success",
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
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
    # For local testing
    test_event = {
        "httpMethod": "POST",
        "body": json.dumps({
            "url": "https://example.com/test.pdf"
        })
    }
    print(json.dumps(lambda_handler(test_event, None), indent=2))
