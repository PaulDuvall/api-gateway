#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
PDF Hash Service Module.

This module provides functionality for generating PDFs, uploading them to S3 via
pre-signed URLs, and computing SHA-256 hashes of file content.

Related User Stories:
- US-400: PDF Generation and Hashing Service
"""

import os
import io
import hashlib
import logging
import boto3
import requests
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
S3_PRESIGNED_URL_EXPIRATION = int(os.environ.get('S3_PRESIGNED_URL_EXPIRATION', '3600'))

if not S3_BUCKET_NAME:
    logger.warning("S3_BUCKET_NAME environment variable not set. Using default bucket name.")
    # Default bucket name used only for local development and testing
    # In production, the bucket name will be set by CloudFormation
    S3_BUCKET_NAME = f"helloworld-pdf-{ENVIRONMENT}-local"


def generate_pdf(title, content):
    """
    Generate a PDF with the given title and content.
    
    Args:
        title (str): The title to display at the top of the PDF
        content (str): The content to include in the PDF
        
    Returns:
        bytes: The generated PDF as bytes
    """
    logger.info(f"Generating PDF with title: {title}")
    
    # Create a buffer to receive PDF data
    buffer = io.BytesIO()
    
    # Create the PDF object using ReportLab
    pdf = canvas.Canvas(buffer, pagesize=letter)
    width, height = letter
    
    # Add title
    pdf.setFont("Helvetica-Bold", 16)
    pdf.drawString(72, height - 72, title)
    
    # Add content
    pdf.setFont("Helvetica", 12)
    y_position = height - 100
    for line in content.split('\n'):
        pdf.drawString(72, y_position, line)
        y_position -= 20
    
    # Add timestamp
    pdf.setFont("Helvetica-Italic", 10)
    import datetime
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    pdf.drawString(72, 72, f"Generated on: {timestamp}")
    
    # Save the PDF
    pdf.save()
    
    # Get the PDF data from the buffer
    pdf_data = buffer.getvalue()
    buffer.close()
    
    logger.info(f"Generated PDF of size {len(pdf_data)} bytes")
    return pdf_data


def create_presigned_url(object_key, expiration=S3_PRESIGNED_URL_EXPIRATION):
    """
    Create a pre-signed URL for uploading an object to S3.
    
    Args:
        object_key (str): The S3 object key
        expiration (int): The expiration time in seconds
        
    Returns:
        str: The pre-signed URL
    """
    logger.info(f"Creating pre-signed URL for object key: {object_key}")
    
    # Create an S3 client
    s3_client = boto3.client('s3')
    
    # Generate a pre-signed URL for the S3 object
    presigned_url = s3_client.generate_presigned_url(
        'put_object',
        Params={'Bucket': S3_BUCKET_NAME, 'Key': object_key},
        ExpiresIn=expiration
    )
    
    logger.info(f"Created pre-signed URL: {presigned_url}")
    return presigned_url


def upload_to_presigned_url(data, presigned_url):
    """
    Upload data to S3 using a pre-signed URL.
    
    Args:
        data (bytes): The data to upload
        presigned_url (str): The pre-signed URL
        
    Returns:
        bool: True if the upload was successful, False otherwise
    """
    logger.info(f"Uploading {len(data)} bytes to pre-signed URL")
    
    # Upload the data to the pre-signed URL
    response = requests.put(
        presigned_url,
        data=data,
        headers={'Content-Type': 'application/pdf'}
    )
    
    # Check if the upload was successful
    if response.status_code == 200:
        logger.info("Upload successful")
        return True
    else:
        logger.error(f"Upload failed with status code: {response.status_code}")
        logger.error(f"Response: {response.text}")
        return False


def download_from_url(url):
    """
    Download content from a URL.
    
    Args:
        url (str): The URL to download from
        
    Returns:
        bytes: The downloaded content
    """
    logger.info(f"Downloading content from URL: {url}")
    
    # Download the content from the URL
    response = requests.get(url)
    
    # Check if the download was successful
    if response.status_code == 200:
        logger.info(f"Download successful, received {len(response.content)} bytes")
        return response.content
    else:
        logger.error(f"Download failed with status code: {response.status_code}")
        logger.error(f"Response: {response.text}")
        raise Exception(f"Failed to download content from URL: {url}")


def compute_sha256(data):
    """
    Compute the SHA-256 hash of the given data.
    
    Args:
        data (bytes): The data to hash
        
    Returns:
        str: The SHA-256 hash as a hexadecimal string
    """
    logger.info(f"Computing SHA-256 hash of {len(data)} bytes")
    
    # Compute the SHA-256 hash
    sha256_hash = hashlib.sha256(data).hexdigest()
    
    logger.info(f"Computed hash: {sha256_hash}")
    return sha256_hash
