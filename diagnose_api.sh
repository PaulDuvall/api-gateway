#!/usr/bin/env bash

# Script to diagnose API Gateway and Lambda integration issues
# Usage: ./diagnose_api.sh <stack-name>
#
# This script performs comprehensive checks on API Gateway and Lambda integration,
# including permissions, configurations, and functionality testing.
# It follows the principles outlined in the Windsurf Global Rules.

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

print_header() {
    echo -e "\n${BLUE}============================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check for required commands
check_prerequisites() {
    local missing_prereqs=false
    
    for cmd in aws jq curl unzip; do
        if ! command -v $cmd &> /dev/null; then
            print_error "Required command not found: $cmd"
            missing_prereqs=true
        fi
    done
    
    if $missing_prereqs; then
        print_error "Please install the missing prerequisites and try again."
        exit 1
    fi
}

# Main execution starts here
check_prerequisites

if [ $# -lt 1 ]; then
    echo "Usage: $0 <stack-name>"
    exit 1
fi

STACK_NAME=$1
OUTPUT_FILE="api_diagnosis_output.json"

# Get stack outputs
print_header "Getting CloudFormation stack outputs for $STACK_NAME"
STACK_OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].Outputs" --output json)

# Extract values from stack outputs
API_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiGateway") | .OutputValue')
LAMBDA_FUNCTION=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunction") | .OutputValue')
API_ENDPOINT=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue')

if [ -z "$API_ID" ] || [ "$API_ID" == "null" ]; then
    print_error "Could not find API Gateway ID in stack outputs"
    exit 1
fi

if [ -z "$LAMBDA_FUNCTION" ] || [ "$LAMBDA_FUNCTION" == "null" ]; then
    print_error "Could not find Lambda function name in stack outputs"
    exit 1
fi

if [ -z "$API_ENDPOINT" ] || [ "$API_ENDPOINT" == "null" ]; then
    print_warning "Could not find API endpoint in stack outputs"
fi

print_success "API Gateway ID: $API_ID"
print_success "Lambda Function: $LAMBDA_FUNCTION"
print_success "API Endpoint: $API_ENDPOINT"

# Check Lambda function
print_header "Checking Lambda function $LAMBDA_FUNCTION"
echo "Invoking Lambda function directly..."
aws lambda invoke --function-name "$LAMBDA_FUNCTION" --payload '{}' "$OUTPUT_FILE"

echo "Lambda function response:"
cat "$OUTPUT_FILE"
echo ""

# Check CloudWatch logs for Lambda function
print_header "Checking CloudWatch logs for Lambda function $LAMBDA_FUNCTION"
LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION"

# Create log group if it doesn't exist (this is idempotent)
echo "Ensuring log group exists and creating it if needed..."
aws logs create-log-group --log-group-name "$LOG_GROUP_NAME" 2>/dev/null || true

# Force a Lambda invocation without parameters to generate logs
echo "Forcing Lambda invocation to generate logs..."
aws lambda invoke --function-name "$LAMBDA_FUNCTION" --payload '{}' "$OUTPUT_FILE" > /dev/null

# Test the API directly to generate logs
echo "Testing API directly to generate logs..."
curl -s "$API_ENDPOINT" > /dev/null
curl -s "$API_ENDPOINT?name=Tester" > /dev/null

# Wait for logs to be available
echo "Waiting for logs to be available..."
sleep 3

LOG_GROUPS=$(aws logs describe-log-groups --query "logGroups[?logGroupName=='$LOG_GROUP_NAME']")
if [ "$(echo "$LOG_GROUPS" | jq 'length')" -eq 0 ]; then
    print_warning "No CloudWatch log group found for Lambda function: $LOG_GROUP_NAME"
    print_warning "This could indicate that the Lambda function has never been invoked or hasn't logged anything."
else
    print_success "Found CloudWatch log group: $LOG_GROUP_NAME"
    
    # Get the latest log stream
    LOG_STREAMS=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP_NAME" --order-by LastEventTime --descending --limit 1)
    LOG_STREAM_NAME=$(echo "$LOG_STREAMS" | jq -r '.logStreams[0].logStreamName')
    
    if [ -n "$LOG_STREAM_NAME" ] && [ "$LOG_STREAM_NAME" != "null" ]; then
        print_success "Latest log stream: $LOG_STREAM_NAME"
        
        # Get the latest log events
        LOG_EVENTS=$(aws logs get-log-events --log-group-name "$LOG_GROUP_NAME" --log-stream-name "$LOG_STREAM_NAME" --limit 30)
        echo "Latest log events:"
        echo "$LOG_EVENTS" | jq -r '.events[] | (.message)' | while read -r line; do
            if [[ "$line" == *"ERROR"* ]] || [[ "$line" == *"error"* ]] || [[ "$line" == *"Error"* ]] || [[ "$line" == *"Exception"* ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo "$line"
            fi
        done
        
        # Specifically look for errors in Lambda execution
        echo -e "\nAnalyzing logs for errors in Lambda execution:"
        ERROR_LOGS=$(echo "$LOG_EVENTS" | jq -r '.events[] | (.message)' | grep -i "error\|exception" || echo "No errors found")
        if [[ "$ERROR_LOGS" == "No errors found" ]]; then
            print_success "No errors found in Lambda execution logs"
        else
            print_error "Found potential errors in Lambda execution:"
            echo -e "${RED}$ERROR_LOGS${NC}"
            
            # Check for specific error patterns
            if [[ "$ERROR_LOGS" == *"permission"* ]]; then
                print_error "Detected permission issues. Check Lambda execution role and API Gateway permissions."
            fi
            
            if [[ "$ERROR_LOGS" == *"timeout"* ]]; then
                print_error "Detected timeout issues. Consider increasing Lambda timeout setting."
            fi
        fi
    else
        print_warning "No log streams found for log group: $LOG_GROUP_NAME"
    fi
fi

# Check Lambda function code packaging
print_header "Checking Lambda function code packaging"

# Check if lambda_function.py exists in the current directory
if [ -f "lambda_function.py" ]; then
    print_success "Found lambda_function.py in the current directory"
    
    # Check if deployment package exists
    if [ -f "lambda_deployment_package.zip" ]; then
        print_success "Found lambda_deployment_package.zip"
        
        # Check content of the deployment package
        print_warning "Checking content of lambda_deployment_package.zip..."
        ZIP_CONTENTS=$(unzip -l lambda_deployment_package.zip | grep lambda_function.py || echo "")
        
        if [ -z "$ZIP_CONTENTS" ]; then
            print_error "lambda_function.py not found in deployment package"
            print_error "This is likely why the Lambda function is failing with 'No module named lambda_function'"
            print_warning "Suggested fix: Run './run.sh deploy' to create and deploy a proper package"
        else
            print_success "lambda_function.py found in deployment package"
        fi
    else
        print_error "lambda_deployment_package.zip not found"
        print_error "This could be why the Lambda function is failing"
        print_warning "Suggested fix: Run './run.sh deploy' to create and deploy the package"
    fi
else
    print_error "lambda_function.py not found in the current directory"
    print_error "This is required for the Lambda function to work"
fi

# Check if the Lambda code was properly deployed
print_warning "Checking if Lambda code was properly deployed..."
LAMBDA_CODE_SIZE=$(aws lambda get-function --function-name "$LAMBDA_FUNCTION" --query "Configuration.CodeSize" --output text 2>/dev/null || echo "0")

if [ "$LAMBDA_CODE_SIZE" -lt 1000 ]; then
    print_error "Lambda function code size is very small ($LAMBDA_CODE_SIZE bytes)"
    print_error "This suggests that only the placeholder code from CloudFormation was deployed"
    print_warning "Suggested fix: Run './run.sh deploy' to update the Lambda function code"
else
    print_success "Lambda function code size looks reasonable ($LAMBDA_CODE_SIZE bytes)"
fi

# Check API Gateway resources
print_header "Checking API Gateway resources for API ID: $API_ID"
RESOURCES=$(aws apigateway get-resources --rest-api-id "$API_ID")
echo "API Gateway resources:"
echo "$RESOURCES" | jq -r '.items[] | "Path: " + .path + (if .resourceMethods then " (Methods: " + ((.resourceMethods | keys) | join(", ")) + ")" else "" end)'

# Find the /hello resource
HELLO_RESOURCE=$(echo "$RESOURCES" | jq -r '.items[] | select(.path=="/hello")')
if [ -z "$HELLO_RESOURCE" ] || [ "$HELLO_RESOURCE" == "null" ]; then
    print_error "Could not find /hello resource in API Gateway"
    exit 1
fi

RESOURCE_ID=$(echo "$HELLO_RESOURCE" | jq -r '.id')
print_success "Found /hello resource with ID: $RESOURCE_ID"

# Check the integration for the GET method
print_header "Checking integration for GET method on /hello resource"
GET_INTEGRATION=$(aws apigateway get-integration --rest-api-id "$API_ID" --resource-id "$RESOURCE_ID" --http-method GET 2>/dev/null || echo '{}')

if [ "$(echo "$GET_INTEGRATION" | jq 'length')" -eq 0 ]; then
    print_error "GET method integration not found"
else
    echo "GET Integration configuration:"
    echo "$GET_INTEGRATION" | jq .
    
    # Check if the integration is correctly configured
    INTEGRATION_TYPE=$(echo "$GET_INTEGRATION" | jq -r '.type')
    INTEGRATION_URI=$(echo "$GET_INTEGRATION" | jq -r '.uri')
    
    if [ "$INTEGRATION_TYPE" != "AWS_PROXY" ]; then
        print_error "GET Integration type is not AWS_PROXY: $INTEGRATION_TYPE"
    else
        print_success "GET Integration type is correctly set to AWS_PROXY"
    fi
    
    if [[ "$INTEGRATION_URI" != *"$LAMBDA_FUNCTION"* ]]; then
        print_error "GET Integration URI does not point to the Lambda function: $INTEGRATION_URI"
    else
        print_success "GET Integration URI correctly points to the Lambda function"
    fi
fi

# Check the integration for the POST method
print_header "Checking integration for POST method on /hello resource"
POST_INTEGRATION=$(aws apigateway get-integration --rest-api-id "$API_ID" --resource-id "$RESOURCE_ID" --http-method POST 2>/dev/null || echo '{}')

if [ "$(echo "$POST_INTEGRATION" | jq 'length')" -eq 0 ]; then
    print_error "POST method integration not found"
else
    echo "POST Integration configuration:"
    echo "$POST_INTEGRATION" | jq .
    
    # Check if the integration is correctly configured
    INTEGRATION_TYPE=$(echo "$POST_INTEGRATION" | jq -r '.type')
    INTEGRATION_URI=$(echo "$POST_INTEGRATION" | jq -r '.uri')
    
    if [ "$INTEGRATION_TYPE" != "AWS_PROXY" ]; then
        print_error "POST Integration type is not AWS_PROXY: $INTEGRATION_TYPE"
    else
        print_success "POST Integration type is correctly set to AWS_PROXY"
    fi
    
    if [[ "$INTEGRATION_URI" != *"$LAMBDA_FUNCTION"* ]]; then
        print_error "POST Integration URI does not point to the Lambda function: $INTEGRATION_URI"
    else
        print_success "POST Integration URI correctly points to the Lambda function"
    fi
fi

# Check Lambda permissions
print_header "Checking Lambda permissions for API Gateway integration"
LAMBDA_POLICY_RESULT=$(aws lambda get-policy --function-name "$LAMBDA_FUNCTION" 2>/dev/null || echo '{}')

if [ "$(echo "$LAMBDA_POLICY_RESULT" | jq 'length')" -eq 0 ]; then
    print_error "Lambda function does not have a resource policy"
    print_error "API Gateway may not have permission to invoke the Lambda function"
else
    LAMBDA_POLICY=$(echo "$LAMBDA_POLICY_RESULT" | jq -r '.Policy' | jq .)
    echo "Lambda function policy:"
    echo "$LAMBDA_POLICY"
    
    # Check for GET method permission
    if [[ "$LAMBDA_POLICY" == *"GET/hello"* ]]; then
        print_success "Lambda policy contains permission for GET method"
    else
        print_error "Lambda policy does not contain permission for GET method"
        print_error "API Gateway may not be able to invoke the Lambda function for GET requests"
    fi
    
    # Check for POST method permission
    if [[ "$LAMBDA_POLICY" == *"POST/hello"* ]]; then
        print_success "Lambda policy contains permission for POST method"
    else
        print_error "Lambda policy does not contain permission for POST method"
        print_error "API Gateway may not be able to invoke the Lambda function for POST requests"
    fi
fi

# Check API Gateway deployment
print_header "Checking API Gateway deployment"
STAGES=$(aws apigateway get-stages --rest-api-id "$API_ID")
echo "API Gateway stages:"
echo "$STAGES" | jq -r '.item[] | "Stage: \(.stageName), Deployed: \(if .deploymentId != null then "true" else "false" end)"'

DEPLOYMENT_COUNT=$(echo "$STAGES" | jq -r '.item[] | select(.deploymentId != null) | .stageName' | wc -l | tr -d ' ')
if [ "$DEPLOYMENT_COUNT" -eq 0 ]; then
    print_error "API Gateway has not been deployed to any stage"
    print_error "You need to deploy the API for it to be accessible"
else
    print_success "API Gateway has been deployed to $DEPLOYMENT_COUNT stage(s)"
fi

# Check API key and usage plan configuration in detail
print_header "Checking API key and usage plan configuration"

# Get all API keys
API_KEYS=$(aws apigateway get-api-keys --include-values --query "items[?contains(name, 'HelloWorld')]")
API_KEY_COUNT=$(echo "$API_KEYS" | jq 'length')

if [ "$API_KEY_COUNT" -eq 0 ]; then
    print_error "No API keys found with 'HelloWorld' in the name"
    print_error "This could be why API requests are failing with 403 Forbidden"
else
    print_success "Found $API_KEY_COUNT API key(s) with 'HelloWorld' in the name"
    
    # Display API keys
    echo "API Keys:"
    echo "$API_KEYS" | jq -r '.[] | "ID: \(.id), Name: \(.name), Value: \(.value[0:5])..., Enabled: \(.enabled)"'
    
    # Check if API key is enabled
    DISABLED_KEYS=$(echo "$API_KEYS" | jq -r '.[] | select(.enabled == false) | .id')
    if [ -n "$DISABLED_KEYS" ]; then
        print_error "Some API keys are disabled. This could cause 403 Forbidden errors."
        echo "$DISABLED_KEYS" | while read -r key_id; do
            echo "Disabled key ID: $key_id"
        done
    else
        print_success "All API keys are enabled"
    fi
fi

# Get all usage plans
USAGE_PLANS=$(aws apigateway get-usage-plans)
USAGE_PLAN_COUNT=$(echo "$USAGE_PLANS" | jq '.items | length')

if [ "$USAGE_PLAN_COUNT" -eq 0 ]; then
    print_error "No usage plans found"
    print_error "API keys need to be associated with a usage plan to work"
else
    print_success "Found $USAGE_PLAN_COUNT usage plan(s)"
    
    # Display usage plans
    echo "Usage Plans:"
    echo "$USAGE_PLANS" | jq -r '.items[] | "ID: \(.id), Name: \(.name), Description: \(.description)"'
    
    # Check if usage plans have API stages
    NO_STAGES_PLANS=$(echo "$USAGE_PLANS" | jq -r '.items[] | select(.apiStages | length == 0) | .id')
    if [ -n "$NO_STAGES_PLANS" ]; then
        print_error "Some usage plans don't have any API stages. This could cause 403 Forbidden errors."
        echo "$NO_STAGES_PLANS" | while read -r plan_id; do
            echo "Usage plan without stages: $plan_id"
        done
    fi
    
    # Check if usage plans have the correct API and stage
    PLANS_WITH_API=$(echo "$USAGE_PLANS" | jq -r --arg api_id "$API_ID" '.items[] | select(.apiStages[] | select(.apiId == $api_id)) | .id')
    if [ -z "$PLANS_WITH_API" ]; then
        print_error "No usage plans are associated with the API ID: $API_ID"
        print_error "This is likely why API requests are failing with 403 Forbidden"
    else
        print_success "Found usage plans associated with the API"
        
        # Check if API keys are associated with usage plans
        echo "Checking API key associations with usage plans..."
        echo "$PLANS_WITH_API" | while read -r plan_id; do
            PLAN_KEYS=$(aws apigateway get-usage-plan-keys --usage-plan-id "$plan_id")
            KEY_COUNT=$(echo "$PLAN_KEYS" | jq '.items | length')
            
            if [ "$KEY_COUNT" -eq 0 ]; then
                print_error "Usage plan $plan_id has no API keys associated with it"
                print_error "This could cause 403 Forbidden errors"
            else
                print_success "Usage plan $plan_id has $KEY_COUNT API key(s) associated with it"
                echo "$PLAN_KEYS" | jq -r '.items[] | "  Key ID: \(.id), Name: \(.name), Value: \(.value[0:5])..."'
            fi
        done
    fi
fi

# Check CORS configuration
print_header "Checking CORS configuration"

# Get OPTIONS method for the /hello resource
OPTIONS_METHOD=$(aws apigateway get-method --rest-api-id "$API_ID" --resource-id "$RESOURCE_ID" --http-method OPTIONS 2>/dev/null || echo '{}')

if [ "$(echo "$OPTIONS_METHOD" | jq 'length')" -eq 0 ]; then
    print_warning "OPTIONS method not found for /hello resource"
    print_warning "CORS may not be properly configured"
    print_warning "This could cause issues when calling the API from browsers"
else
    print_success "OPTIONS method found for /hello resource"
    echo "OPTIONS method configuration:"
    echo "$OPTIONS_METHOD" | jq .
    
    # Check for CORS headers in the response
    RESPONSE_PARAMS=$(aws apigateway get-method-response --rest-api-id "$API_ID" --resource-id "$RESOURCE_ID" --http-method OPTIONS --status-code 200 2>/dev/null | jq -r '.responseParameters')
    
    if [[ "$RESPONSE_PARAMS" == *"Access-Control-Allow-Origin"* ]]; then
        print_success "CORS headers found in OPTIONS method response"
    else
        print_warning "CORS headers not found in OPTIONS method response"
        print_warning "This could cause issues when calling the API from browsers"
    fi
fi

# Test API with API key
print_header "Testing API with API key"

# Get API key ID from stack outputs
API_KEY_ID=$(echo "$STACK_OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiKeyId") | .OutputValue')

if [ -z "$API_KEY_ID" ] || [ "$API_KEY_ID" == "null" ]; then
    print_error "Could not find API Key ID in stack outputs"
else
    print_success "Found API Key ID: $API_KEY_ID"
    
    # Get API key value
    print_warning "Retrieving API key value..."
    API_KEY_VALUE=$(aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query "value" --output text)
    
    if [ -z "$API_KEY_VALUE" ]; then
        print_error "Could not retrieve API key value"
    else
        print_success "Retrieved API key value"
        
        # Test GET method without parameters
        print_warning "Testing GET method without parameters..."
        echo -e "${YELLOW}curl -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT\"${NC}"
        GET_RESPONSE=$(curl -s -H "x-api-key: $API_KEY_VALUE" "$API_ENDPOINT")
        echo "Response: $GET_RESPONSE"
        
        # Check if GET response is successful
        if [[ "$GET_RESPONSE" == *"success"* ]]; then
            print_success "GET request was successful"
        elif [[ "$GET_RESPONSE" == *"Internal server error"* ]]; then
            print_error "GET request returned internal server error"
            print_error "Check Lambda function logs for details"
        elif [[ "$GET_RESPONSE" == *"Missing Authentication Token"* ]]; then
            print_error "GET request returned 'Missing Authentication Token'"
            print_error "This usually indicates a routing issue in API Gateway"
        else
            print_warning "GET request returned an unexpected response"
        fi
        
        # Test GET method with name parameter
        print_warning "\nTesting GET method with name parameter..."
        echo -e "${YELLOW}curl -H \"x-api-key: $API_KEY_VALUE\" \"$API_ENDPOINT?name=TestUser\"${NC}"
        GET_PARAM_RESPONSE=$(curl -s -H "x-api-key: $API_KEY_VALUE" "$API_ENDPOINT?name=TestUser")
        echo "Response: $GET_PARAM_RESPONSE"
        
        # Check if GET with parameter response is successful
        if [[ "$GET_PARAM_RESPONSE" == *"TestUser"* ]]; then
            print_success "GET request with parameter was successful"
        elif [[ "$GET_PARAM_RESPONSE" == *"Internal server error"* ]]; then
            print_error "GET request with parameter returned internal server error"
            print_error "Check Lambda function logs for details"
        else
            print_warning "GET request with parameter returned an unexpected response"
        fi
        
        # Test POST method
        print_warning "\nTesting POST method..."
        echo -e "${YELLOW}curl -X POST -H \"Content-Type: application/json\" -H \"x-api-key: $API_KEY_VALUE\" -d '{\"name\":\"PostUser\",\"message\":\"This is a POST request!\"}' \"$API_ENDPOINT\"${NC}"
        POST_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -H "x-api-key: $API_KEY_VALUE" -d '{"name":"PostUser","message":"This is a POST request!"}' "$API_ENDPOINT")
        echo "Response: $POST_RESPONSE"
        
        # Check if POST response is successful
        if [[ "$POST_RESPONSE" == *"PostUser"* ]]; then
            print_success "POST request was successful"
        elif [[ "$POST_RESPONSE" == *"Internal server error"* ]]; then
            print_error "POST request returned internal server error"
            print_error "Check Lambda function logs for details"
        elif [[ "$POST_RESPONSE" == *"Missing Authentication Token"* ]]; then
            print_error "POST request returned 'Missing Authentication Token'"
            print_error "This usually indicates a routing issue in API Gateway"
            print_error "Ensure the POST method is properly configured in API Gateway"
        else
            print_warning "POST request returned an unexpected response"
        fi
    fi
fi

# Test the API endpoint
if [ -n "$API_ENDPOINT" ] && [ "$API_ENDPOINT" != "null" ]; then
    print_header "Testing API endpoint: $API_ENDPOINT"
    echo "Making request to API endpoint..."
    RESPONSE=$(curl -s "$API_ENDPOINT")
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_ENDPOINT")
    
    echo "HTTP Status: $HTTP_STATUS"
    echo "Response body:"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    
    if [ "$HTTP_STATUS" -eq 200 ]; then
        print_success "API endpoint returned 200 OK"
    else
        print_error "API endpoint returned non-200 status code: $HTTP_STATUS"
    fi
    
    # Test with query parameter
    echo -e "\nTesting API endpoint with query parameter..."
    PARAM_RESPONSE=$(curl -s "$API_ENDPOINT?name=Tester")
    PARAM_HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$API_ENDPOINT?name=Tester")
    
    echo "HTTP Status: $PARAM_HTTP_STATUS"
    echo "Response body:"
    echo "$PARAM_RESPONSE" | jq . 2>/dev/null || echo "$PARAM_RESPONSE"
    
    if [ "$PARAM_HTTP_STATUS" -eq 200 ]; then
        print_success "API endpoint with query parameter returned 200 OK"
    else
        print_error "API endpoint with query parameter returned non-200 status code: $PARAM_HTTP_STATUS"
    fi
else
    print_warning "No API endpoint available for testing"
fi

# Provide a summary of findings
print_header "Diagnostic Summary"

echo -e "${BLUE}API Gateway:${NC}"
echo -e "  - API ID: $API_ID"
echo -e "  - API Endpoint: $API_ENDPOINT"

echo -e "\n${BLUE}Lambda Function:${NC}"
echo -e "  - Function Name: $LAMBDA_FUNCTION"

echo -e "\n${BLUE}API Methods:${NC}"
echo -e "  - GET Method: $([ "$(echo "$GET_INTEGRATION" | jq 'length')" -ne 0 ] && echo "${GREEN}Configured${NC}" || echo "${RED}Not Configured${NC}")"
echo -e "  - POST Method: $([ "$(echo "$POST_INTEGRATION" | jq 'length')" -ne 0 ] && echo "${GREEN}Configured${NC}" || echo "${RED}Not Configured${NC}")"
echo -e "  - OPTIONS Method (CORS): $([ "$(echo "$OPTIONS_METHOD" | jq 'length')" -ne 0 ] && echo "${GREEN}Configured${NC}" || echo "${YELLOW}Not Configured${NC}")"

echo -e "\n${BLUE}Lambda Permissions:${NC}"
echo -e "  - GET Permission: $([[ "$LAMBDA_POLICY" == *"GET/hello"* ]] && echo "${GREEN}Granted${NC}" || echo "${RED}Not Granted${NC}")"
echo -e "  - POST Permission: $([[ "$LAMBDA_POLICY" == *"POST/hello"* ]] && echo "${GREEN}Granted${NC}" || echo "${RED}Not Granted${NC}")"

echo -e "\n${BLUE}API Testing Results:${NC}"
echo -e "  - GET Request: $([ -n "$GET_RESPONSE" ] && [[ "$GET_RESPONSE" == *"success"* ]] && echo "${GREEN}Successful${NC}" || echo "${RED}Failed${NC}")"
echo -e "  - GET Request with Parameter: $([ -n "$GET_PARAM_RESPONSE" ] && [[ "$GET_PARAM_RESPONSE" == *"TestUser"* ]] && echo "${GREEN}Successful${NC}" || echo "${RED}Failed${NC}")"
echo -e "  - POST Request: $([ -n "$POST_RESPONSE" ] && [[ "$POST_RESPONSE" == *"PostUser"* ]] && echo "${GREEN}Successful${NC}" || echo "${RED}Failed${NC}")"

echo -e "\n${BLUE}Next Steps:${NC}"
echo -e "1. Review any errors in the diagnostic output above"
echo -e "2. Check CloudWatch logs for detailed Lambda function errors"
echo -e "3. Verify API Gateway configuration in the AWS Console"
echo -e "4. Ensure Lambda function code correctly handles both GET and POST requests"
echo -e "5. Redeploy the API if any changes were made"

echo -e "\n${BLUE}For more information, see the README.md file in the api_gateway directory.${NC}"

print_header "Diagnosis Complete"
echo "If you encountered any issues, check the suggested fixes above."
echo "For more information, refer to the troubleshooting section in the README.md file."
