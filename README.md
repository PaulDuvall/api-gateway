# API Gateway & Lambda Automation Project

This repository implements a robust, production-ready API platform using AWS Lambda, API Gateway, and CloudFormation, following modern Python and DevOps best practices.

---

## Features
- Python 3.11, modular code in `src/api_gateway/`
- Lambda functions: `lambda_function.py`, `pdf_hash_lambda.py`
- PDF hash client/service modules
- Infrastructure as Code (IaC) with `template.yaml`
- Parameter Store integration for configuration
- Automated tests with pytest
- Diagnostic script: `diagnose_api.sh`
- Automated deployment: `run.sh` (see below)
- API key management and throttling
- CI/CD with GitHub Actions
- Follows twelve-factor app methodology
- Security best practices (see `.awssecurityrules.md`, `.iamrolerules.md`)

## Prerequisites
- Python 3.11+
- AWS CLI configured
- AWS account with permissions for Lambda, API Gateway, IAM, SSM

## Getting Started

### Setup
```bash
chmod +x run.sh
./run.sh setup
```
Creates a virtualenv and installs all dependencies.

### Testing
```bash
./run.sh test
```
Runs all tests in `tests/`.

### Deployment & Automation

#### Complete Deployment
```bash
./run.sh all
```
- Sets up venv, runs tests, packages both Lambda functions, deploys via CloudFormation.

#### Individual Steps
- **Test only:** `./run.sh test`
- **Package Lambda:** `./run.sh package`
- **Package PDF Hash Lambda:** `./run.sh pdf-package`
- **Deploy via CloudFormation:** `./run.sh cloudformation`
- **Deploy Lambda only:** `./run.sh deploy`
- **Update Lambda code only:** `./run.sh update-lambda`
- **Update PDF Hash Lambda code only:** `./run.sh update-pdf-lambda`
- **Test API endpoint:** `./run.sh test-api`
- **Test PDF Hash API endpoint:** `./run.sh test-pdf-hash`

### API Endpoints
- Endpoints are output in `output.json` after deployment.
- Example: `/prod/hello`, `/prod/pdf-hash`

## Security & Best Practices
- No secrets or credentials are tracked (see `.gitignore`)
- See `.awssecurityrules.md`, `.iamrolerules.md` for security policies
- API keys managed securely, never committed

## GitHub Actions OIDC Setup for AWS

This project supports secure, secretless AWS authentication in CI/CD using GitHub Actions OIDC and the [`gha-aws-oidc-bootstrap`](https://github.com/PaulDuvall/gha-aws-oidc-bootstrap) repository.

### Why OIDC?
- Removes the need to store AWS credentials as GitHub secrets
- Uses short-lived, least-privilege credentials for each workflow run
- Follows AWS and GitHub security best practices

### Setup Instructions
1. **Bootstrap AWS OIDC trust for your GitHub repo:**
   - Follow the instructions in [gha-aws-oidc-bootstrap](https://github.com/PaulDuvall/gha-aws-oidc-bootstrap#quickstart) to create the required IAM roles and trust relationships for your repo.
   - Example:
     ```bash
     git clone https://github.com/PaulDuvall/gha-aws-oidc-bootstrap.git
     cd gha-aws-oidc-bootstrap
     ./bootstrap.sh --repo PaulDuvall/api-gateway --region us-east-1
     ```
   - This will output the IAM Role ARN to use in your workflow.
2. **Update your GitHub Actions workflow** to use the OIDC role:
   - See the workflow section below for usage.
3. **Remove static AWS credentials** from GitHub secrets if present.

### Usage in GitHub Actions
- The workflow automatically authenticates to AWS using the OIDC role.
- No need to set `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` secrets.
- See `.github/workflows/run-all.yml` for an example.

## Documentation & Project Rules
- Project rules: `.awssecurityrules.md`, `.cicdrules.md`, `.iamrolerules.md`, `.refactoringrules.md`, `.windsurfrules.md`, `global_rules.md`
- Architecture diagrams: `docs/architecture_diagrams.md`
- For user stories and traceability, see `docs/user_stories.md`, `docs/traceability_matrix.md`

## Contributing
- Follow coding standards and rules in the `.md` rules files
- All changes must pass tests and CI
- Never commit secrets or sensitive data

---

For more details, see the documentation files in the repo. If you have questions or want to extend the platform, check the rules and standards before making changes.

### Testing

Run the tests to ensure everything is working correctly:

```bash
./run.sh test
```

### Creating a Deployment Package

Create a ZIP package for AWS Lambda deployment:

```bash
./run.sh package
```

This will create `lambda_deployment_package.zip` in the project directory.

## Deployment Options

### Option 1: Complete Deployment (Recommended)

Run all steps (setup, test, package, and deploy) with a single command:

```bash
./run.sh all
```

This will:
1. Set up the Python virtual environment and install dependencies
2. Run all tests to ensure everything is working correctly
3. Create the Lambda deployment package
4. Deploy everything using CloudFormation (Lambda function, API Gateway, IAM roles, etc.)

### Option 2: CloudFormation Deployment

Deploy the entire solution (Lambda function, API Gateway, IAM roles, and Parameter Store configuration) using CloudFormation:

```bash
./run.sh cloudformation
```

This will:
1. Create or update a CloudFormation stack named "HelloWorldApiStack"
2. Deploy all necessary resources
3. Update the Lambda function code
4. Provide you with the API endpoint URL

### Option 3: Manual Lambda Deployment

If you prefer to deploy just the Lambda function and configure API Gateway manually:

```bash
./run.sh deploy
```

This will:
1. Create or update the Lambda function
2. Add necessary permissions
3. Guide you through the next steps for API Gateway setup

## API Documentation

### Endpoints

#### GET /hello

Returns a greeting message with the current timestamp.

**Query Parameters:**

- `name` (optional): Personalize the greeting with a name. Default: "World"

**Authentication:**

- Requires an API key in the `x-api-key` header

**Response:**

```json
{
  "message": "Hello, World! The time is 2025-03-23 10:10:15.",
  "status": "success",
  "timestamp": "2025-03-23T10:10:15.123456",
  "version": "1.1.0",
  "environment": "prod"
}
```

**Example Requests:**

```bash
# Basic request with API key
curl -H "x-api-key: YOUR_API_KEY" "https://vnv8g46uml.execute-api.us-east-1.amazonaws.com/prod/hello"

# With name parameter (note the quotes around the URL to escape the ? character in zsh/bash)
curl -H "x-api-key: YOUR_API_KEY" "https://vnv8g46uml.execute-api.us-east-1.amazonaws.com/prod/hello?name=PMD"
```

#### POST /hello

Handles JSON payloads with `name` and optional `message` parameters.

**Request Body:**

```json
{
  "name": "PostUser",
  "message": "This is a POST request!"
}
```

**Authentication:**

- Requires an API key in the `x-api-key` header

**Response:**

```json
{
  "message": "Hello, PostUser! The time is 2025-03-25 22:15:30. This is a POST request!",
  "status": "success",
  "timestamp": "2025-03-25T22:15:30.987654",
  "version": "1.1.0",
  "environment": "prod",
  "method": "POST"
}
```

**Example Request:**

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: YOUR_API_KEY" \
  -d '{"name":"PostUser","message":"This is a POST request!"}' \
  "https://your-api-id.execute-api.region.amazonaws.com/prod/hello"
```

#### OPTIONS /hello

Returns CORS headers for browser compatibility.

**Response:**

```http
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, x-api-key
```

### API Throttling

The API is configured with throttling to prevent abuse:

- **Rate Limit**: 0.033 requests per second (2 requests per minute)
- **Burst Limit**: 2 requests

If you exceed these limits, you'll receive a 429 Too Many Requests response.

## Project Structure

```
## Project Structure

```text
api-gateway/
├── src/
│   └── api_gateway/
│       ├── __init__.py
│       ├── lambda_function.py      # Main Lambda function handler
│       ├── pdf_hash_lambda.py      # PDF hash Lambda handler
│       ├── pdf_hash_client.py      # PDF hash client logic
│       └── pdf_hash_service.py     # PDF hash service logic
├── requirements.txt                # Python dependencies
├── requirements-dev.txt            # Development dependencies
├── requirements-prod.txt           # Production dependencies
├── template.yaml                   # CloudFormation template (IaC)
├── run.sh                          # Main automation script (build, test, deploy)
├── diagnose_api.sh                 # Diagnostic script for API Gateway and Lambda
├── manage_api_key.sh               # Script for API key management
├── pytest.ini                      # Pytest configuration
├── output.json                     # Deployment outputs (endpoints, ARNs)
├── docs/
│   ├── architecture_diagrams.md    # AWS/cloud architecture diagrams
│   ├── user_stories.md             # User stories documentation
│   └── traceability_matrix.md      # Traceability matrix
├── tests/                          # Unit and integration tests
├── .github/
│   └── workflows/
│       └── run-all.yml             # GitHub Actions workflow
├── .gitignore
├── .awssecurityrules.md            # AWS security best practices
├── .cicdrules.md                   # CI/CD standards
├── .iamrolerules.md                # IAM role standards
├── .refactoringrules.md            # Refactoring guidelines
├── .windsurfrules.md               # Windsurf project rules
├── global_rules.md                 # Centralized global rules
└── README.md                       # Project documentation
```

```

### Resource Naming Conventions

This project follows AWS best practices for resource naming to ensure compatibility and uniqueness:

1. **Lambda Function Names**: Uses underscores as separators in the format `${LambdaFunctionName}_${StageName}_${DeploymentTimestamp}`
   - Example: `HelloWorldFunction_prod_20250404095806`

2. **API Gateway Stage Names**: Uses lowercase letters for stage names
   - Example: `prod`, `dev`, `test`

3. **API Keys and Usage Plans**: Includes timestamps to ensure uniqueness
   - Example: `HelloWorldApiKey_20250404095806`

## API Key Management

### Managing API Keys

The project includes a script for managing API keys:

```bash
# Make the script executable
chmod +x manage_api_key.sh

# Create a new API key (replace with your stack name and stage)
./manage_api_key.sh create HelloWorldApiStack prod

# List all existing API keys
./manage_api_key.sh list

# Delete an API key (replace with your API key ID)
./manage_api_key.sh delete YOUR_API_KEY_ID
```

The script provides the following functionality:

1. **Creating API Keys**: Creates a new API key, sets up a usage plan with throttling, and associates the key with the plan
2. **Listing API Keys**: Shows all existing API keys in your AWS account
3. **Deleting API Keys**: Removes an API key from your AWS account

### Retrieving API Key Values

There are several ways to retrieve your API key value:

#### 1. After Deployment

When you run `./run.sh cloudformation` or `./run.sh all`, the API key value is displayed in the console output and saved to the `.env` file.

#### 2. Using the API Key Management Script

```bash
# Make the script executable
chmod +x manage_api_key.sh

# Retrieve API key value from stack
./manage_api_key.sh get-api-key HelloWorldApiStack
```

This will display the API key information including the API key value and example curl commands.

#### 3. Manual Retrieval Using AWS CLI

You can also manually retrieve the API key value using AWS CLI commands:

```bash
# First, get the API key ID from the stack outputs
API_KEY_ID=$(aws cloudformation describe-stacks --stack-name HelloWorldApiStack --query "Stacks[0].Outputs[?OutputKey=='ApiKeyId'].OutputValue" --output text)

# Then, get the API key value
aws apigateway get-api-key --api-key $API_KEY_ID --include-value --query "value" --output text
```

## Testing the API

The project includes a built-in command to test the API with your API key:

```bash
./run.sh test-api
```

This will:

1. Retrieve the API endpoint and key from CloudFormation outputs
2. Make test requests to the API
3. Display the responses

Example output:
```
=== Testing API with API Key ===

[WARN] Getting stack outputs...
[OK] Found API endpoint: https://your-api-id.execute-api.region.amazonaws.com/prod/hello
[OK] Found API Key ID: your-api-key-id
[WARN] Retrieving API key value...
[OK] Retrieved API key value.
[WARN] Testing API without parameters...
curl -H "x-api-key: your-api-key-value" "https://your-api-id.execute-api.region.amazonaws.com/prod/hello"

Response: {"message":"Hello, World! The time is 2025-03-26 15:30:45.","status":"success","timestamp":"2025-03-26T15:30:45.123456","version":"1.1.0","environment":"prod"}

[WARN] Testing API with name parameter...
curl -H "x-api-key: your-api-key-value" "https://your-api-id.execute-api.region.amazonaws.com/prod/hello?name=TestUser"

Response: {"message":"Hello, TestUser! The time is 2025-03-26 15:30:46.","status":"success","timestamp":"2025-03-26T15:30:46.789012","version":"1.1.0","environment":"prod"}
```

## Architecture

This project follows AWS best practices and the Well-Architected Framework:

1. **Serverless Architecture**: Uses AWS Lambda and API Gateway for a fully serverless solution with no servers to manage.

2. **Security**:
   - Implemented API key authentication to secure API access
   - Added API throttling to prevent abuse and control costs

3. **Operational Excellence**:
   - Environment-Aware Configuration: The Lambda function now uses environment variables and adapts its behavior based on the environment (dev/prod).
   - Comprehensive error handling and logging
   - Diagnostic script for troubleshooting API Gateway and Lambda integration

4. **CI/CD Pipeline**: Added GitHub Actions workflow for automated testing and deployment.

## Troubleshooting

### Common Issues

1. **Lambda Function Not Found**
   - Ensure the Lambda function is deployed correctly
   - Check the function name in the CloudFormation outputs
   - Verify the function exists in the AWS Lambda console

2. **API Key Not Working**
   - Ensure the API key is enabled and associated with the correct usage plan
   - Verify you're including the API key in the `x-api-key` header
   - Check the API key value using the `manage_api_key.sh` script

3. **CloudFormation Deployment Failures**
   - Check the CloudFormation events in the AWS Console for specific error messages
   - Ensure you have the necessary permissions to create all resources
   - Verify the CloudFormation template is valid

4. **Lambda Function Errors**
   - Check the CloudWatch logs for the Lambda function
   - Ensure the function has the necessary permissions
   - Verify the function code is correct

5. **API Gateway Configuration Issues**
   - Run the diagnostic script: `./diagnose_api.sh HelloWorldApiStack`
   - Ensure the API Gateway is configured correctly
   - Verify the API Gateway is deployed to the correct stage
   - Check the API Gateway logs in CloudWatch

6. **API Gateway and Lambda Integration Issues**
   - Ensure the API Gateway integration is set to AWS_PROXY and uses POST as the integration HTTP method
   - Verify the Lambda function returns a properly formatted response with statusCode, headers, and body
   - Check CloudWatch logs for any errors in the Lambda function execution

7. **Missing API Key (HTTP 403 Forbidden)**
   - If you receive a "Missing Authentication Token" or "Forbidden" error, ensure you're including the API key in your request
   - The API key must be included in the `x-api-key` header: `curl -H "x-api-key: YOUR_API_KEY" "https://your-api-endpoint"`
   - Verify the API key is valid and enabled in the AWS Console
   - Check that the API key is associated with the correct usage plan

8. **API Throttling (HTTP 429 Too Many Requests)**
   - If you receive a "Too Many Requests" error, you've exceeded the throttling limits (2 requests per minute)
   - Wait before making additional requests
   - If you need higher limits, modify the usage plan in the AWS Console or update the `manage_api_key.sh` script

### API Gateway "Internal Server Error"

If you encounter an "Internal server error" when invoking your API Gateway endpoint, it's often due to permission issues between API Gateway and Lambda. Here are steps to diagnose and fix the issue:

1. **Use the Diagnostic Script**: Run the included diagnostic script to automatically check your API Gateway and Lambda configuration:

   ```bash
   ./diagnose_api.sh HelloWorldApiStack
   ```

   This script will:
   - Check Lambda function configuration and test direct invocation
   - Verify CloudWatch logs are being generated
   - Examine API Gateway resources and integration settings
   - Validate Lambda permissions
   - Test the API endpoint
   - Provide suggested fixes for any issues found

2. **Common Issues and Fixes**:

   - **Lambda Permission Issue**: The most common cause is that API Gateway doesn't have permission to invoke your Lambda function. The fix is to add the correct permission:

     ```bash
     aws lambda add-permission \
       --function-name <your-lambda-function-name> \
       --statement-id apigateway-permission \
       --action lambda:InvokeFunction \
       --principal apigateway.amazonaws.com \
       --source-arn "arn:aws:execute-api:<region>:<account-id>:<api-id>/*/GET/hello"
     ```

   - **Source ARN Format**: Note that the source ARN should use a wildcard for the stage (`/*`) to work with all stages.

   - **API Gateway Deployment**: After making permission changes, you may need to create a new deployment:

     ```bash
     aws apigateway create-deployment --rest-api-id <api-id> --stage-name prod
     ```

3. **URL Query Parameter Escaping**: When using query parameters with special characters, ensure they are properly URL-encoded.

### CloudWatch Logs

If you need to check the Lambda function logs:

```bash
aws logs get-log-streams --log-group-name /aws/lambda/<your-lambda-function-name>
aws logs get-log-events --log-group-name /aws/lambda/<your-lambda-function-name> --log-stream-name <log-stream-name>
```

## References

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [Amazon API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/welcome.html)
- [AWS CloudFormation User Guide](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html)
- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [API Gateway Usage Plans and API Keys](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-api-usage-plans.html)
- [API Gateway Request Throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)
- [Twelve-Factor App Methodology](https://12factor.net/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
