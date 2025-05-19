#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
PDF Hash Client.

This module provides a client for generating PDFs, uploading them to S3 via
pre-signed URLs, and computing SHA-256 hashes via an API Gateway endpoint.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import os
import json
import uuid
import logging
import requests
import argparse
from datetime import datetime

# Import the PDF hash service functions
from pdf_hash_service import generate_pdf, create_presigned_url, upload_to_presigned_url

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
API_ENDPOINT = os.environ.get('API_ENDPOINT', 'https://example.com/prod/pdf-hash')
API_KEY = os.environ.get('API_KEY', '')
# S3 bucket name is now dynamically generated and passed via environment variables
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')

if not S3_BUCKET_NAME:
    logger.warning("S3_BUCKET_NAME environment variable not set. Using default bucket name for local development.")
    # Default bucket name used only for local development and testing
    # In production, the bucket name will be set by CloudFormation
    S3_BUCKET_NAME = f"helloworld-pdf-{ENVIRONMENT}-local"


def invoke_api(api_endpoint, api_key, presigned_url):
    """
    Invoke the PDF hash API with the pre-signed URL.
    
    Args:
        api_endpoint (str): The API endpoint URL
        api_key (str): The API key
        presigned_url (str): The pre-signed URL to the PDF
        
    Returns:
        dict: The API response
    """
    logger.info(f"Invoking API endpoint: {api_endpoint}")
    
    # Prepare the request headers and body
    headers = {
        'x-api-key': api_key,
        'Content-Type': 'application/json'
    }
    body = {
        'url': presigned_url
    }
    
    # Make the API request
    response = requests.post(api_endpoint, headers=headers, json=body)
    
    # Check if the request was successful
    if response.status_code == 200:
        logger.info("API request successful")
        return response.json()
    else:
        logger.error(f"API request failed with status code: {response.status_code}")
        logger.error(f"Response: {response.text}")
        raise Exception(f"Failed to invoke API: {response.text}")


def generate_and_hash_pdf(title, content):
    """
    Generate a PDF, upload it to S3, and compute its hash via the API.
    
    Args:
        title (str): The title for the PDF
        content (str): The content for the PDF
        
    Returns:
        str: The SHA-256 hash of the PDF
    """
    logger.info(f"Starting PDF generation and hashing workflow for title: {title}")
    
    try:
        # Generate the PDF
        pdf_data = generate_pdf(title, content)
        
        # Generate a unique object key for S3
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        object_key = f"pdf/{timestamp}_{uuid.uuid4()}.pdf"
        
        # Create a pre-signed URL for uploading to S3
        presigned_url = create_presigned_url(object_key)
        
        # Upload the PDF to S3 using the pre-signed URL
        upload_success = upload_to_presigned_url(pdf_data, presigned_url)
        if not upload_success:
            raise Exception("Failed to upload PDF to S3")
        
        # Invoke the API to compute the hash
        api_response = invoke_api(API_ENDPOINT, API_KEY, presigned_url)
        
        # Extract the hash from the API response
        if api_response.get('status') == 'success' and 'hash' in api_response:
            pdf_hash = api_response['hash']
            logger.info(f"PDF hash: {pdf_hash}")
            return pdf_hash
        else:
            raise Exception(f"API returned an error: {api_response}")
    
    except Exception as e:
        logger.error(f"Error in PDF generation and hashing workflow: {str(e)}")
        raise


def main():
    """
    Main function to run the PDF hash client from the command line.
    """
    parser = argparse.ArgumentParser(description='Generate a PDF and compute its SHA-256 hash.')
    parser.add_argument('--title', type=str, default='Sample PDF', help='Title for the PDF')
    parser.add_argument('--content', type=str, default='This is a sample PDF generated for testing.', 
                        help='Content for the PDF')
    parser.add_argument('--api-endpoint', type=str, help='API endpoint URL')
    parser.add_argument('--api-key', type=str, help='API key')
    parser.add_argument('--s3-bucket', type=str, help='S3 bucket name')
    
    args = parser.parse_args()
    
    # Override environment variables with command line arguments if provided
    if args.api_endpoint:
        global API_ENDPOINT
        API_ENDPOINT = args.api_endpoint
    
    if args.api_key:
        global API_KEY
        API_KEY = args.api_key
    
    if args.s3_bucket:
        global S3_BUCKET_NAME
        S3_BUCKET_NAME = args.s3_bucket
    
    # Check if API key is available
    if not API_KEY:
        logger.error("API key is required. Set the API_KEY environment variable or use --api-key.")
        return 1
    
    # Check if S3 bucket name is available
    if not S3_BUCKET_NAME:
        logger.error("S3 bucket name is required. Set the S3_BUCKET_NAME environment variable or use --s3-bucket.")
        return 1
    
    try:
        # Run the workflow
        pdf_hash = generate_and_hash_pdf(args.title, args.content)
        print(f"\nPDF Hash: {pdf_hash}\n")
        return 0
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return 1


if __name__ == "__main__":
    exit(main())
