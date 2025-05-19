#!/bin/bash

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
NC="\033[0m" # No Color

# Function to print colored output
print_message() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to get the API ID from CloudFormation stack
get_api_id() {
  local stack_name=$1
  aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --query "Stacks[0].Outputs[?OutputKey=='ApiId'].OutputValue" \
    --output text
}

# Function to get API key value from stack
get_api_key_value() {
  local stack_name=$1
  
  print_message "$YELLOW" "Getting API key value from stack $stack_name..."
  
  # Get API Key ID from CloudFormation stack
  local api_key_id=$(aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --query "Stacks[0].Outputs[?OutputKey=='ApiKeyId'].OutputValue" \
    --output text)
  
  if [ -z "$api_key_id" ]; then
    print_message "$RED" "Error: Could not find API Key ID in stack $stack_name"
    exit 1
  fi
  
  print_message "$GREEN" "✓ Found API Key ID: $api_key_id"
  
  # Get API key value
  local api_key_value=$(aws apigateway get-api-key \
    --api-key "$api_key_id" \
    --include-value \
    --query "value" \
    --output text)
  
  if [ -z "$api_key_value" ]; then
    print_message "$RED" "Error: Could not retrieve API key value"
    exit 1
  fi
  
  # Get API endpoint
  local api_endpoint=$(aws cloudformation describe-stacks \
    --stack-name "$stack_name" \
    --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
    --output text)
  
  # Print summary with color
  echo -e "${GREEN}\n============================================================${NC}"
  echo -e "${GREEN}API Key Information${NC}"
  echo -e "${GREEN}============================================================${NC}"
  echo -e "${GREEN}API Key ID: $api_key_id${NC}"
  echo -e "${GREEN}API Key Value: $api_key_value${NC}"
  echo -e "${GREEN}\nTo use the API, include the API key in your requests:${NC}"
  echo -e "${GREEN}\n# GET request examples:${NC}"
  echo -e "${GREEN}curl -H \"x-api-key: $api_key_value\" $api_endpoint${NC}"
  echo -e "${GREEN}curl -H \"x-api-key: $api_key_value\" ${api_endpoint}?name=YourName${NC}"
  echo -e "${GREEN}\n# POST request example:${NC}"
  echo "curl -X POST -H \"Content-Type: application/json\" -H \"x-api-key: $api_key_value\" -d '{\"name\":\"PostUser\",\"message\":\"This is a POST request!\"}' $api_endpoint"
  echo -e "${GREEN}============================================================${NC}"
}

# Function to create an API key
create_api_key() {
  local api_name=$1
  local api_id=$2
  local stage_name=$3
  
  # Create API key
  print_message "$YELLOW" "Creating API key for $api_name..."
  local api_key_id=$(aws apigateway create-api-key \
    --name "${api_name}Key" \
    --description "API Key for $api_name" \
    --enabled \
    --query "id" \
    --output text)
  
  print_message "$GREEN" "✓ API key created with ID: $api_key_id"
  
  # Create usage plan
  print_message "$YELLOW" "Creating usage plan..."
  local usage_plan_id=$(aws apigateway create-usage-plan \
    --name "${api_name}UsagePlan" \
    --description "Usage plan for $api_name" \
    --api-stages "apiId=$api_id,stage=$stage_name" \
    --throttle "rateLimit=0.033,burstLimit=2" \
    --query "id" \
    --output text)
  
  print_message "$GREEN" "✓ Usage plan created with ID: $usage_plan_id"
  
  # Associate API key with usage plan
  print_message "$YELLOW" "Associating API key with usage plan..."
  aws apigateway create-usage-plan-key \
    --usage-plan-id "$usage_plan_id" \
    --key-id "$api_key_id" \
    --key-type "API_KEY" > /dev/null
  
  print_message "$GREEN" "✓ API key associated with usage plan"
  
  # Get API key value
  local api_key_value=$(aws apigateway get-api-key \
    --api-key "$api_key_id" \
    --include-value \
    --query "value" \
    --output text)
  
  print_message "$GREEN" "✓ API key value: $api_key_value"
  
  # Update method to require API key
  print_message "$YELLOW" "Updating API method to require API key..."
  
  # Get resource ID for /hello
  local resource_id=$(aws apigateway get-resources \
    --rest-api-id "$api_id" \
    --query "items[?path=='/hello'].id" \
    --output text)
  
  aws apigateway update-method \
    --rest-api-id "$api_id" \
    --resource-id "$resource_id" \
    --http-method "GET" \
    --patch-operations "op=replace,path=/apiKeyRequired,value=true" > /dev/null
  
  print_message "$GREEN" "✓ API method updated to require API key"
  
  # Deploy API to apply changes
  print_message "$YELLOW" "Deploying API to apply changes..."
  aws apigateway create-deployment \
    --rest-api-id "$api_id" \
    --stage-name "$stage_name" \
    --description "Deployment to apply API key requirement" > /dev/null
  
  print_message "$GREEN" "✓ API deployed successfully"
  
  # Print summary
  echo -e "${GREEN}\n============================================================${NC}"
  echo -e "${GREEN}API Key Setup Complete${NC}"
  echo -e "${GREEN}============================================================${NC}"
  echo -e "${GREEN}API Key ID: $api_key_id${NC}"
  echo -e "${GREEN}API Key Value: $api_key_value${NC}"
  echo -e "${GREEN}Usage Plan ID: $usage_plan_id${NC}"
  echo -e "${GREEN}\nTo use the API, include the API key in your requests:${NC}"
  echo -e "${GREEN}\n# GET request examples:${NC}"
  echo -e "${GREEN}curl -H \"x-api-key: $api_key_value\" https://$api_id.execute-api.$(aws configure get region).amazonaws.com/$stage_name/hello${NC}"
  echo -e "${GREEN}curl -H \"x-api-key: $api_key_value\" https://$api_id.execute-api.$(aws configure get region).amazonaws.com/$stage_name/hello?name=YourName${NC}"
  echo -e "${GREEN}\n# POST request example:${NC}"
  echo "curl -X POST -H \"Content-Type: application/json\" -H \"x-api-key: $api_key_value\" -d '{\"name\":\"PostUser\",\"message\":\"This is a POST request!\"}' https://$api_id.execute-api.$(aws configure get region).amazonaws.com/$stage_name/hello"
  echo -e "${GREEN}============================================================${NC}"
}

# Function to list existing API keys
list_api_keys() {
  print_message "$YELLOW" "Listing existing API keys..."
  aws apigateway get-api-keys --query "items[].{ID:id,Name:name,Description:description,Enabled:enabled}" --output table
}

# Function to delete an API key
delete_api_key() {
  local api_key_id=$1
  
  print_message "$YELLOW" "Deleting API key $api_key_id..."
  aws apigateway delete-api-key --api-key "$api_key_id"
  print_message "$GREEN" "✓ API key deleted successfully"
}

# Main function
main() {
  if [ $# -lt 1 ]; then
    print_message "$RED" "Error: Missing command"
    print_message "$YELLOW" "Usage: $0 [create|list|delete|get-api-key] [stack_name] [stage_name]"
    print_message "$YELLOW" "  create: Create a new API key and usage plan"
    print_message "$YELLOW" "  list: List existing API keys"
    print_message "$YELLOW" "  delete: Delete an API key"
    print_message "$YELLOW" "  get-api-key: Get API key value from stack"
    exit 1
  fi
  
  local command=$1
  
  case "$command" in
    create)
      if [ $# -lt 3 ]; then
        print_message "$RED" "Error: Missing stack_name or stage_name"
        print_message "$YELLOW" "Usage: $0 create <stack_name> <stage_name>"
        exit 1
      fi
      local stack_name=$2
      local stage_name=$3
      local api_id=$(get_api_id "$stack_name")
      
      if [ -z "$api_id" ]; then
        print_message "$RED" "Error: Could not find API ID for stack $stack_name"
        exit 1
      fi
      
      create_api_key "HelloWorld" "$api_id" "$stage_name"
      ;;
    list)
      list_api_keys
      ;;
    delete)
      if [ $# -lt 2 ]; then
        print_message "$RED" "Error: Missing api_key_id"
        print_message "$YELLOW" "Usage: $0 delete <api_key_id>"
        exit 1
      fi
      local api_key_id=$2
      delete_api_key "$api_key_id"
      ;;
    get-api-key)
      if [ $# -lt 2 ]; then
        print_message "$RED" "Error: Missing stack_name"
        print_message "$YELLOW" "Usage: $0 get-api-key <stack_name>"
        exit 1
      fi
      local stack_name=$2
      get_api_key_value "$stack_name"
      ;;
    *)
      print_message "$RED" "Error: Unknown command $command"
      print_message "$YELLOW" "Usage: $0 [create|list|delete|get-api-key]"
      exit 1
      ;;
  esac
}

# Execute main function
main "$@"
