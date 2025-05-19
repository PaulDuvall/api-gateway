#!/bin/bash

# Hello World API Gateway + Lambda Setup Script
# This script sets up a Python virtual environment, installs dependencies,
# and provides utilities for testing and deploying the Lambda function with API Gateway.

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[OK] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Setup virtual environment
setup_venv() {
    print_section "Setting up Python virtual environment"
    
    # Check if Python 3.11 is available
    if ! command_exists python3.11; then
        print_warning "Python 3.11 not found. Checking for Python 3.x..."
        
        if command_exists python3; then
            PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
            print_warning "Using Python $PYTHON_VERSION instead of 3.11"
            PYTHON_CMD="python3"
        else
            print_error "Python 3.x is required but not found. Please install Python 3.11 or later."
        fi
    else
        PYTHON_CMD="python3.11"
        print_success "Found Python 3.11"
    fi
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        $PYTHON_CMD -m venv venv
        print_success "Created virtual environment"
    else
        print_warning "Virtual environment already exists"
    fi
    
    # Activate virtual environment
    source venv/bin/activate
    print_success "Activated virtual environment"
    
    # Upgrade pip
    pip install --upgrade pip
    print_success "Upgraded pip to latest version"
    
    # Install dependencies
    pip install -r requirements.txt
    print_success "Installed dependencies from requirements.txt"
}

# Run tests
run_tests() {
    print_section "Running tests"
    source venv/bin/activate
    python3 -m pytest tests/unit -v
}

# Create deployment package
create_deployment_package() {
    print_section "Creating deployment package"
    source venv/bin/activate
    
    # Completely remove any existing package directory and zip file
    rm -rf package
    rm -f lambda_deployment_package.zip
    
    # Create a fresh package directory
    mkdir -p package
    
    # Copy only the Lambda function to the package directory
    cp lambda_function.py package/
    
    # Create the ZIP file
    cd package
    zip -r ../lambda_deployment_package.zip .
    cd ..
    
    # Check the size of the deployment package
    PACKAGE_SIZE=$(du -h lambda_deployment_package.zip | cut -f1)
    print_success "Created minimal deployment package: lambda_deployment_package.zip (Size: $PACKAGE_SIZE)"
}

# Create PDF hash deployment package
create_pdf_hash_deployment_package() {
    print_section "Creating PDF hash deployment package"
    source venv/bin/activate
    
    # Completely remove any existing package directory and zip file
    rm -rf package
    rm -f pdf_hash_deployment_package.zip
    
    # Create a fresh package directory
    mkdir -p package
    
    # Copy the Lambda function and service module to the package directory
    cp pdf_hash_lambda.py package/
    cp pdf_hash_service.py package/
    
    # Install dependencies to the package directory
    pip install -r requirements-prod.txt --target package/
    
    # Create the ZIP file
    cd package
    zip -r ../pdf_hash_deployment_package.zip .
    cd ..
    
    # Check the size of the deployment package
    PACKAGE_SIZE=$(du -h pdf_hash_deployment_package.zip | cut -f1)
    print_success "Created PDF hash deployment package: pdf_hash_deployment_package.zip (Size: $PACKAGE_SIZE)"
}

# Deploy to AWS using CloudFormation
deploy_cloudformation() {
    print_section "Deploying to AWS using CloudFormation"
    
    # Create deployment packages first
    create_deployment_package
    create_pdf_hash_deployment_package
    
    # Check if AWS CLI is configured - either through aws configure or environment variables
    if [[ -z "${AWS_REGION}" && -z "${AWS_DEFAULT_REGION}" ]] && ! aws configure get region >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first or set AWS_REGION environment variable."
    fi
    
    # Use environment variable if available, otherwise get from AWS CLI config
    REGION=${AWS_REGION:-$(aws configure get region 2>/dev/null || echo "us-east-1")}
    
    # Get the current timestamp for unique resource names
    TIMESTAMP=${TIMESTAMP:-$(date +"%Y%m%d%H%M%S")}
    
    # Deploy CloudFormation stack
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
        # Update existing stack
        print_warning "Stack '$STACK_NAME' already exists. Updating..."
        
        # Create a change set for the update
        CHANGE_SET_NAME="${STACK_NAME}-change-set-${TIMESTAMP}"
        
        aws cloudformation create-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME" \
            --template-body file://template.yaml \
            --parameters ParameterKey=DeploymentTimestamp,ParameterValue=$TIMESTAMP ParameterKey=StageName,ParameterValue=${ENVIRONMENT:-prod} ParameterKey=ProjectIdentifier,ParameterValue=helloworld \
            --capabilities CAPABILITY_IAM
        
        # Wait for change set creation to complete
        aws cloudformation wait change-set-create-complete \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME"
        
        # Execute the change set
        aws cloudformation execute-change-set \
            --stack-name "$STACK_NAME" \
            --change-set-name "$CHANGE_SET_NAME"
        
        print_section "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME"
        
        print_success "Stack '$STACK_NAME' updated successfully"
    else
        # Create new stack
        print_warning "Stack '$STACK_NAME' does not exist. Creating..."
        
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body file://template.yaml \
            --parameters ParameterKey=DeploymentTimestamp,ParameterValue=$TIMESTAMP ParameterKey=StageName,ParameterValue=${ENVIRONMENT:-prod} ParameterKey=ProjectIdentifier,ParameterValue=helloworld \
            --capabilities CAPABILITY_IAM
        
        print_section "Waiting for stack creation to complete..."
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME"
        
        print_success "Stack '$STACK_NAME' created successfully"
    fi
    
    # Get the outputs from the CloudFormation stack
    STACK_OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --query "Stacks[0].Outputs" \
        --output json)
    
    # Extract the API endpoint and Lambda function name
    API_ENDPOINT=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue')
    LAMBDA_FUNCTION=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunction") | .OutputValue')
    PDF_HASH_FUNCTION=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="PdfHashFunction") | .OutputValue')
    PDF_HASH_API_ENDPOINT=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="PdfHashApiEndpoint") | .OutputValue')
    API_KEY_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiKeyId") | .OutputValue')
    S3_BUCKET_NAME=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="S3BucketName") | .OutputValue')
    
    # Save the outputs to a file for reference
    echo "$STACK_OUTPUTS" > output.json
    print_success "Stack outputs saved to output.json"
    
    # Update the Lambda function code
    print_section "Updating Lambda function code"
    
    aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION" \
        --zip-file fileb://lambda_deployment_package.zip \
        --region "$REGION"
    
    print_success "Updated Lambda function code for $LAMBDA_FUNCTION"
    
    # Update the PDF Hash Lambda function code
    print_section "Updating PDF Hash Lambda function code"
    
    aws lambda update-function-code \
        --function-name "$PDF_HASH_FUNCTION" \
        --zip-file fileb://pdf_hash_deployment_package.zip \
        --region "$REGION"
    
    print_success "Updated Lambda function code for $PDF_HASH_FUNCTION"
    
    # Get the API key value
    print_section "Getting API Key"
    API_KEY_VALUE=$(aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query "value" --output text 2>/dev/null)
    
    print_success "API Key retrieved successfully"
    
    # Print deployment information
    print_section "Deployment Information"
    echo "API Endpoint: $API_ENDPOINT"
    echo "PDF Hash API Endpoint: $PDF_HASH_API_ENDPOINT"
    echo "Lambda Function: $LAMBDA_FUNCTION"
    echo "PDF Hash Lambda Function: $PDF_HASH_FUNCTION"
    echo "API Key ID: $API_KEY_ID"
    echo "API Key Value: $API_KEY_VALUE"
    echo "S3 Bucket Name: $S3_BUCKET_NAME"
    
    # Save environment variables to .env file
    cat > .env << EOF
# Generated on $(date)
API_ENDPOINT=$API_ENDPOINT
PDF_HASH_API_ENDPOINT=$PDF_HASH_API_ENDPOINT
API_KEY_ID=$API_KEY_ID
API_KEY_VALUE=$API_KEY_VALUE
S3_BUCKET_NAME=$S3_BUCKET_NAME
LAMBDA_FUNCTION=$LAMBDA_FUNCTION
PDF_HASH_FUNCTION=$PDF_HASH_FUNCTION
ENVIRONMENT=${ENVIRONMENT:-prod}
EOF
    
    print_success "Environment variables saved to .env file"
    echo "To load the environment variables, run: source .env"
    
    # Print example curl commands
    print_section "Example API Commands"
    echo -e "${BLUE}# GET request to Hello World API:${NC}"
    echo -e "curl -s -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT\""
    echo ""
    
    echo -e "${BLUE}# GET request with name parameter:${NC}"
    echo -e "curl -s -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT?name=YourName\""
    echo ""
    
    echo -e "${BLUE}# POST request to Hello World API:${NC}"
    echo -e "curl -X POST -s -H \"Content-Type: application/json\" -H \"x-api-key: $API_KEY_VALUE\" -d '{\"name\":\"YourName\"}' \"$API_ENDPOINT\""
    echo ""
    
    print_success "All steps completed successfully!"
}

# Function to test the API with API key
test_api() {
    print_section "Testing the API with API key"
    source venv/bin/activate
    
    # Check if jq is installed
    if ! command_exists jq; then
        print_error "jq is required for this command. Please install jq first."
    fi
    
    # Get the API endpoint and key from environment variables or CloudFormation outputs
    if [ -z "$API_ENDPOINT" ] || [ -z "$API_KEY" ]; then
        if [ -f "output.json" ]; then
            print_warning "API_ENDPOINT or API_KEY not set. Attempting to get from CloudFormation outputs..."
            
            API_ENDPOINT=$(jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue' output.json)
            API_KEY_ID=$(jq -r '.[] | select(.OutputKey=="ApiKeyId") | .OutputValue' output.json)
            
            # Get the API key value
            API_KEY=$(aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query "value" --output text 2>/dev/null)
            
            print_success "Retrieved API endpoint and key from CloudFormation outputs"
        else
            print_error "API_ENDPOINT and API_KEY environment variables must be set or output.json must exist"
        fi
    fi
    
    # Test the basic endpoint
    print_section "Testing basic endpoint"
    echo -e "API Endpoint: ${BLUE}$API_ENDPOINT${NC}"
    echo -e "API Key: ${BLUE}${API_KEY:0:5}...${NC}"
    
    RESPONSE=$(curl -s -H "x-api-key: $API_KEY" "$API_ENDPOINT")
    echo -e "Response: ${BLUE}$RESPONSE${NC}"
    
    # Test with a name parameter
    print_section "Testing with name parameter"
    RESPONSE=$(curl -s -H "x-api-key: $API_KEY" "$API_ENDPOINT?name=TestUser")
    echo -e "Response: ${BLUE}$RESPONSE${NC}"
    
    # Test without API key (should fail)
    print_section "Testing without API key (should fail)"
    RESPONSE=$(curl -s "$API_ENDPOINT")
    echo -e "Response: ${BLUE}$RESPONSE${NC}"
    
    print_success "API tests completed"
}

# Function to test the PDF hash API
test_pdf_hash_api() {
    print_section "Testing PDF Hash API Workflow"
    source venv/bin/activate
    
    # Check if AWS CLI is installed
    if ! command_exists aws; then
        print_warning "AWS CLI is not found. Will use manual configuration."
        USE_MANUAL_CONFIG=true
    else
        USE_MANUAL_CONFIG=false
        
        # Get AWS account ID
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            print_warning "Failed to get AWS account ID. Will use manual configuration."
            USE_MANUAL_CONFIG=true
        fi
        
        # Get AWS region
        AWS_REGION=$(aws configure get region 2>/dev/null)
        if [ -z "$AWS_REGION" ]; then
            print_warning "Failed to get AWS region. Will use manual configuration."
            USE_MANUAL_CONFIG=true
        fi
        
        # Get current timestamp
        TIMESTAMP=$(date +"%Y%m%d%H%M%S")
        
        if [ "$USE_MANUAL_CONFIG" = false ]; then
            # Try to get API Gateway endpoint and API key from CloudFormation outputs
            print_warning "Retrieving API Gateway endpoint and API key from CloudFormation outputs..."
            API_ENDPOINT=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PdfHashApiEndpoint'].OutputValue" --output text 2>/dev/null)
            API_KEY_ID=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='ApiKeyId'].OutputValue" --output text 2>/dev/null)
            
            if [ -z "$API_ENDPOINT" ] || [ "$API_ENDPOINT" == "None" ]; then
                print_warning "Failed to retrieve API endpoint from CloudFormation. Will use manual configuration."
                USE_MANUAL_CONFIG=true
            fi
            
            if [ -z "$API_KEY_ID" ] || [ "$API_KEY_ID" == "None" ]; then
                print_warning "Failed to retrieve API key ID from CloudFormation. Will use manual configuration."
                USE_MANUAL_CONFIG=true
            fi
            
            if [ "$USE_MANUAL_CONFIG" = false ]; then
                # Get API key value
                API_KEY_VALUE=$(aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query "value" --output text 2>/dev/null)
                
                if [ -z "$API_KEY_VALUE" ]; then
                    print_warning "Failed to retrieve API key value. Will use manual configuration."
                    USE_MANUAL_CONFIG=true
                fi
            fi
        fi
    fi
    
    # Use manual configuration if automatic retrieval failed
    if [ "$USE_MANUAL_CONFIG" = true ]; then
        print_section "Manual Configuration"
        print_warning "CloudFormation stack not found or AWS CLI not configured properly."
        print_warning "Please provide the following information manually:"
        
        # Check if environment variables are already set
        if [ -z "$API_ENDPOINT" ]; then
            read -p "Enter your PDF Hash API endpoint (e.g., https://abc123.execute-api.region.amazonaws.com/prod/pdf-hash): " API_ENDPOINT
        fi
        
        if [ -z "$API_KEY" ]; then
            read -p "Enter your API key: " API_KEY_VALUE
        else
            API_KEY_VALUE="$API_KEY"
        fi
        
        if [ -z "$S3_BUCKET_NAME" ]; then
            read -p "Enter your S3 bucket name: " S3_BUCKET_NAME
        fi
        
        if [ -z "$ENVIRONMENT" ]; then
            ENVIRONMENT="test"
        fi
    else
        # Set environment variables for testing
        export ENVIRONMENT="test"
        export S3_BUCKET_NAME="helloworld-pdf-${ENVIRONMENT}-${AWS_ACCOUNT_ID}-${AWS_REGION}-${TIMESTAMP}"
    fi
    
    # Set environment variables for the client
    export API_ENDPOINT="$API_ENDPOINT"
    export API_KEY="$API_KEY_VALUE"
    
    print_success "Environment variables set:"
    print_success "  ENVIRONMENT: $ENVIRONMENT"
    print_success "  S3_BUCKET_NAME: $S3_BUCKET_NAME"
    print_success "  API_ENDPOINT: $API_ENDPOINT"
    print_success "  API_KEY: [HIDDEN]"
    
    print_warning "Running PDF hash workflow test..."
    # Run the PDF hash client
    HASH_RESULT=$(python3 pdf_hash_client.py "Test PDF" "This is a test PDF document generated on $(date).")
    
    if [ $? -eq 0 ] && [ ! -z "$HASH_RESULT" ]; then
        print_success "PDF hash workflow test completed successfully!"
        print_success "SHA-256 Hash: $HASH_RESULT"
        
        print_section "PDF Hash API Usage Examples"
        echo -e "Example 1: Generate a PDF and compute its hash using the client script:"
        echo -e "  python3 pdf_hash_client.py \"Your PDF Title\" \"Your PDF Content\""
        echo -e ""
        echo -e "Example 2: Call the PDF hash API directly with curl:"
        echo -e "  curl -X POST \\
  -H \"Content-Type: application/json\" \\
  -H \"x-api-key: $API_KEY_VALUE\" \\
  -d '{\"url\":\"https://your-s3-bucket.s3.amazonaws.com/your-pdf-key\"}' \\
  \"$API_ENDPOINT\""
        
        print_section "Environment Variables for Future Use"
        echo -e "Add these to your shell configuration or .env file:"
        echo -e "export API_ENDPOINT=\"$API_ENDPOINT\""
        echo -e "export API_KEY=\"$API_KEY_VALUE\""
        echo -e "export S3_BUCKET_NAME=\"$S3_BUCKET_NAME\""
    else
        print_error "PDF hash workflow test failed. Check the error messages above."
        
        print_section "Troubleshooting"
        echo -e "1. Verify that your AWS credentials are properly configured:"
        echo -e "   aws configure"
        echo -e ""
        echo -e "2. Ensure that the CloudFormation stack is deployed:"
        echo -e "   ./run.sh all"
        echo -e ""
        echo -e "3. Check that the S3 bucket exists and is accessible:"
        echo -e "   aws s3 ls s3://$S3_BUCKET_NAME"
        echo -e ""
        echo -e "4. Verify that the API Gateway endpoint is correct:"
        echo -e "   curl -H \"x-api-key: $API_KEY_VALUE\" \"${API_ENDPOINT%/pdf-hash}/hello\""
        echo -e ""
        echo -e "5. Check the CloudWatch logs for the Lambda function:"
        echo -e "   aws logs get-log-streams --log-group-name /aws/lambda/PdfHashFunction-prod-*"
    fi
}

# Deploy to AWS (manual Lambda + API Gateway)
deploy_to_aws() {
    print_section "Deploying to AWS (manual Lambda + API Gateway)"
    
    # Create deployment package first
    create_deployment_package
    
    # Check if AWS CLI is configured
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install it first."
    fi
    
    # Check if AWS CLI is configured - either through aws configure or environment variables
    if [[ -z "${AWS_REGION}" && -z "${AWS_DEFAULT_REGION}" ]] && ! aws configure get region >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first or set AWS_REGION environment variable."
    fi
    
    # Get AWS account ID
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        print_error "Failed to get AWS account ID. Please check your AWS credentials."
    fi
    
    # Function name
    FUNCTION_NAME="HelloWorldFunction"
    
    # Check if Lambda role exists or create it
    LAMBDA_ROLE_NAME="HelloWorldLambdaRole"
    LAMBDA_ROLE="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"
    
    if ! aws iam get-role --role-name "$LAMBDA_ROLE_NAME" >/dev/null 2>&1; then
        print_warning "Lambda role does not exist. Creating..."
        
        # Create a trust policy document for Lambda
        cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
        
        # Create the role
        aws iam create-role \
            --role-name "$LAMBDA_ROLE_NAME" \
            --assume-role-policy-document file://trust-policy.json \
            --output text >/dev/null
        
        # Attach the AWSLambdaBasicExecutionRole policy
        aws iam attach-role-policy \
            --role-name "$LAMBDA_ROLE_NAME" \
            --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" \
            --output text >/dev/null
        
        print_success "Created Lambda role: $LAMBDA_ROLE_NAME"
        
        # Wait for the role to propagate
        print_warning "Waiting for the role to propagate..."
        sleep 10
    else
        print_success "Using existing Lambda role: $LAMBDA_ROLE_NAME"
    fi
    
    # Check if Lambda function exists
    if aws lambda get-function --function-name "$FUNCTION_NAME" >/dev/null 2>&1; then
        # Update existing function
        print_warning "Function $FUNCTION_NAME already exists. Updating..."
        aws lambda update-function-code \
            --function-name "$FUNCTION_NAME" \
            --zip-file fileb://lambda_deployment_package.zip
        print_success "Updated Lambda function: $FUNCTION_NAME"
    else
        # Create new function
        print_warning "Function $FUNCTION_NAME does not exist. Creating..."
        LAMBDA_RESPONSE=$(aws lambda create-function \
            --function-name "$FUNCTION_NAME" \
            --runtime python3.11 \
            --handler lambda_function.lambda_handler \
            --role "$LAMBDA_ROLE" \
            --zip-file fileb://lambda_deployment_package.zip)
        
        if [ $? -eq 0 ]; then
            print_success "Created Lambda function: $FUNCTION_NAME"
            
            # Add API Gateway permission
            aws lambda add-permission \
                --function-name "$FUNCTION_NAME" \
                --statement-id apigateway \
                --action lambda:InvokeFunction \
                --principal apigateway.amazonaws.com \
                --source-arn "arn:aws:execute-api:$(aws configure get region):${AWS_ACCOUNT_ID}:*/*/*/hello" \
                --output text >/dev/null
            
            print_success "Added API Gateway permission to Lambda function"
        else
            print_error "Failed to create Lambda function. Please check your AWS credentials and permissions."
        fi
    fi
    
    print_warning "NOTE: For a fully automated deployment including API Gateway, use the 'cloudformation' command."
    print_section "Next Steps for Manual API Gateway Setup"
    echo -e "1. Go to the AWS Management Console and navigate to API Gateway"
    echo -e "2. Click 'Create API' and select 'REST API'"
    echo -e "3. Name your API (e.g., 'HelloWorldAPI') and click 'Create API'"
    echo -e "4. Click 'Create Resource' and name it (e.g., 'hello')"
    echo -e "5. With the resource selected, click 'Create Method' and select 'GET'"
    echo -e "6. Configure the GET method:"
    echo -e "   - Integration type: Lambda Function"
    echo -e "   - Lambda Function: $FUNCTION_NAME"
    echo -e "   - Use Default Timeout: Yes"
    echo -e "7. Deploy the API:"
    echo -e "   - Click 'Deploy API'"
    echo -e "   - Deployment stage: [New Stage]"
    echo -e "   - Stage name: 'prod'"
    echo -e "8. You'll receive an Invoke URL to test your API"
}

# Function to update Lambda function code
update_lambda_function() {
    print_section "Updating Lambda function code"
    source venv/bin/activate
    
    # Create deployment package
    create_deployment_package
    
    # Check if AWS CLI is configured
    if [[ -z "${AWS_REGION}" && -z "${AWS_DEFAULT_REGION}" ]] && ! aws configure get region >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first or set AWS_REGION environment variable."
    fi
    
    # Get Lambda function name from environment or CloudFormation outputs
    if [ -z "$LAMBDA_FUNCTION" ]; then
        if [ -f "output.json" ]; then
            print_warning "LAMBDA_FUNCTION not set. Attempting to get from CloudFormation outputs..."
            LAMBDA_FUNCTION=$(jq -r '.[] | select(.OutputKey=="LambdaFunction") | .OutputValue' output.json)
            
            if [ -z "$LAMBDA_FUNCTION" ] || [ "$LAMBDA_FUNCTION" == "null" ]; then
                print_error "Could not find Lambda function name in CloudFormation outputs"
                exit 1
            fi
            
            print_success "Retrieved Lambda function name: $LAMBDA_FUNCTION"
        else
            print_error "LAMBDA_FUNCTION environment variable must be set or output.json must exist"
            exit 1
        fi
    fi
    
    # Update Lambda function code
    print_warning "Updating Lambda function code for $LAMBDA_FUNCTION..."
    RESULT=$(aws lambda update-function-code \
        --function-name "$LAMBDA_FUNCTION" \
        --zip-file fileb://lambda_deployment_package.zip)
    
    if [ $? -eq 0 ]; then
        print_success "Successfully updated Lambda function code"
        print_success "Function ARN: $(echo "$RESULT" | jq -r '.FunctionArn')"
        print_success "Last Modified: $(echo "$RESULT" | jq -r '.LastModified')"
        
        # Also update PDF Hash function if it exists
        if [ -f "output.json" ]; then
            PDF_HASH_FUNCTION=$(jq -r '.[] | select(.OutputKey=="PdfHashFunction") | .OutputValue' output.json)
            
            if [ -n "$PDF_HASH_FUNCTION" ] && [ "$PDF_HASH_FUNCTION" != "null" ]; then
                print_warning "PDF Hash function found. To update it, run './run.sh update-pdf-lambda'."
            fi
        fi
        
        print_section "Testing commands"
        # Load environment variables
        if [ -f ".env" ]; then
            source .env
            
            # Print example curl commands
            echo -e "${BLUE}# GET request to Hello World API:${NC}"
            echo -e "curl -s -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT\""
            echo ""
            
            echo -e "${BLUE}# GET request with name parameter:${NC}"
            echo -e "curl -s -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT?name=YourName\""
            echo ""
            
            echo -e "${BLUE}# POST request to Hello World API:${NC}"
            echo -e "curl -X POST -s -H \"Content-Type: application/json\" -H \"x-api-key: $API_KEY_VALUE\" -d '{\"name\":\"YourName\"}' \"$API_ENDPOINT\""
        else
            print_warning "No .env file found. Run './run.sh cloudformation' to create it."
        fi
    else
        print_error "Failed to update Lambda function code"
    fi
}

# Function to update PDF Hash Lambda function code
update_pdf_hash_function() {
    print_section "Updating PDF Hash Lambda function code"
    source venv/bin/activate
    
    # Create deployment package
    create_pdf_hash_deployment_package
    
    # Check if AWS CLI is configured
    if [[ -z "${AWS_REGION}" && -z "${AWS_DEFAULT_REGION}" ]] && ! aws configure get region >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first or set AWS_REGION environment variable."
    fi
    
    # Get Lambda function name from environment or CloudFormation outputs
    if [ -z "$PDF_HASH_FUNCTION" ]; then
        if [ -f "output.json" ]; then
            print_warning "PDF_HASH_FUNCTION not set. Attempting to get from CloudFormation outputs..."
            PDF_HASH_FUNCTION=$(jq -r '.[] | select(.OutputKey=="PdfHashFunction") | .OutputValue' output.json)
            
            if [ -z "$PDF_HASH_FUNCTION" ] || [ "$PDF_HASH_FUNCTION" == "null" ]; then
                print_error "Could not find PDF Hash function name in CloudFormation outputs"
                exit 1
            fi
            
            print_success "Retrieved PDF Hash function name: $PDF_HASH_FUNCTION"
        else
            print_error "PDF_HASH_FUNCTION environment variable must be set or output.json must exist"
            exit 1
        fi
    fi
    
    # Update Lambda function code
    print_warning "Updating PDF Hash function code for $PDF_HASH_FUNCTION..."
    RESULT=$(aws lambda update-function-code \
        --function-name "$PDF_HASH_FUNCTION" \
        --zip-file fileb://pdf_hash_deployment_package.zip)
    
    if [ $? -eq 0 ]; then
        print_success "Successfully updated PDF Hash function code"
        print_success "Function ARN: $(echo "$RESULT" | jq -r '.FunctionArn')"
        print_success "Last Modified: $(echo "$RESULT" | jq -r '.LastModified')"
        
        print_section "Testing commands"
        # Load environment variables
        if [ -f ".env" ]; then
            source .env
            
            print_success "PDF Hash function code updated successfully"
        else
            print_warning "No .env file found. Run './run.sh cloudformation' to create it."
        fi
    else
        print_error "Failed to update PDF Hash function code"
    fi
}

# Print usage information
usage() {
    echo -e "\nUsage: $0 [command]\n"
    echo -e "Commands:"
    echo -e "  setup           Set up Python virtual environment and install dependencies"
    echo -e "  test            Run tests"
    echo -e "  package         Create deployment package for AWS Lambda"
    echo -e "  pdf-package     Create deployment package for PDF Hash Lambda"
    echo -e "  deploy          Deploy Lambda function to AWS (manual API Gateway setup)"
    echo -e "  cloudformation  Deploy Lambda function and API Gateway using CloudFormation (recommended)"
    echo -e "  update-lambda   Update Lambda function code without redeploying CloudFormation stack"
    echo -e "  update-pdf-lambda Update PDF Hash Lambda function code without redeploying CloudFormation stack"
    echo -e "  all             Run all steps: setup, test, package, and cloudformation deployment"
    echo -e "  help            Show this help message"
    echo -e "  test-api        Test the API with API key"
    echo -e "  test-pdf-hash   Test the PDF Hash API workflow"
    echo -e "\n"
}

# Main script logic
STACK_NAME="${STACK_NAME:-HelloWorldApiStack}"
case "$1" in
    setup)
        setup_venv
        ;;
    test)
        setup_venv
        run_tests
        ;;
    package)
        setup_venv
        create_deployment_package
        ;;
    pdf-package)
        setup_venv
        create_pdf_hash_deployment_package
        ;;
    deploy)
        setup_venv
        deploy_to_aws
        ;;
    cloudformation)
        setup_venv
        deploy_cloudformation
        ;;
    update-lambda)
        setup_venv
        update_lambda_function
        ;;
    update-pdf-lambda)
        setup_venv
        update_pdf_hash_function
        ;;
    all)
        print_section "Running complete deployment process"
        setup_venv
        run_tests
        create_deployment_package
        create_pdf_hash_deployment_package
        # Set environment variables for the deployment
        export ENVIRONMENT="prod"
        export TIMESTAMP=$(date +"%Y%m%d%H%M%S")
        deploy_cloudformation
        print_success "All steps completed successfully!"
        ;;
    test-api)
        setup_venv
        test_api
        ;;
    test-pdf-hash)
        setup_venv
        test_pdf_hash_api
        ;;
    *)
        usage
        ;;
esac

# If no arguments provided, run setup
if [ $# -eq 0 ]; then
    setup_venv
    print_success "Setup complete. Run '$0 help' for more options."
fi
