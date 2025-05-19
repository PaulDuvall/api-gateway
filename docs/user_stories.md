# API Gateway User Stories

## API Key Management and Throttling

### US-300: API Key Management

**As a** developer using the Hello World API,  
**I want to** easily manage API keys for authentication,  
**So that** I can control access to the API and maintain security.

**Acceptance Criteria:**
- API keys can be created, listed, and deleted through a command-line interface
- API keys are automatically associated with usage plans
- API methods are properly configured to require API keys
- Clear documentation is provided for API key management

**Implementation Details:**
- Created `manage_api_key.sh` script with commands for creating, listing, and deleting API keys
- Integrated API key creation with CloudFormation deployment
- Updated API Gateway configuration to require API keys for endpoints

### US-301: API Throttling

**As an** API provider,  
**I want to** implement throttling on API requests,  
**So that** I can prevent abuse and control costs.

**Acceptance Criteria:**
- API requests are limited to a configurable rate (e.g., 2 requests per minute)
- Burst limits are properly configured
- Throttling is tied to API keys for per-client control
- Throttling configuration is defined as infrastructure as code

**Implementation Details:**
- Implemented throttling through API Gateway usage plans
- Set rate limit to 2 requests per minute with a burst limit of 2
- Associated usage plans with API keys
- Defined throttling configuration in CloudFormation template

### US-302: Automated API Key Retrieval

**As a** developer deploying the Hello World API,  
**I want to** automatically retrieve API key values after deployment,  
**So that** I can immediately test and use the API without manual steps.

**Acceptance Criteria:**
- API key values are automatically displayed after deployment
- The process handles API key retrieval securely
- Clear instructions are provided for using the API key

**Implementation Details:**
- Enhanced `run.sh` to automatically retrieve and display API key values after deployment
- Added a `get-api-key` command to `manage_api_key.sh` for retrieving API key values from stacks
- Updated documentation with examples of API key retrieval

### US-303: Automated API Testing with Authentication

**As a** developer or CI/CD pipeline,  
**I want to** automatically test the API with the correct API key,  
**So that** I can verify API functionality and authentication are working correctly.

**Acceptance Criteria:**
- API can be tested with a single command
- Tests include both basic and parameterized requests
- API key is automatically retrieved and used for authentication
- Test results are clearly displayed

**Implementation Details:**
- Added a `test-api` command to `run.sh` for automated API testing
- Implemented automatic API key retrieval for tests
- Updated GitHub Actions workflow to include API testing after deployment
- Enhanced documentation with examples of automated testing

## API Enhancement Features

### US-304: Enhanced POST & GET Method Support with Well-Architected Principles

**As a** developer using the Hello World API,  
**I want to** securely submit data via POST requests and retrieve data via GET requests (both requiring API key authentication),  
**So that** I can create, update, and retrieve resources on the server with robust validation, error handling, observability, and adherence to AWS Well-Architected principles.

#### Acceptance Criteria:

- **POST Requests:**
  - The `/hello` endpoint supports POST requests.
  - POST requests require API key authentication.
  - API Gateway enforces built-in request validation for JSON payloads, ensuring required fields (e.g., `name`) are present.
  - Mapping templates standardize the incoming payload before it reaches the Lambda function.
  - The Lambda function correctly processes JSON payloads with distinct logic for POST requests.
  - Comprehensive error handling is implemented for malformed JSON and other exceptions.
  - POST requests are properly throttled according to a well-defined usage plan, including rate and burst limits.
  - Proper CORS configuration is in place, including a dedicated OPTIONS method for preflight requests.

- **GET Requests:**
  - The `/hello` endpoint supports GET requests.
  - GET requests require API key authentication.
  - The Lambda function processes GET requests separately with appropriate response handling.
  - Consistent CORS configuration is maintained for GET responses.

- **General Enhancements (Aligned with AWS Well-Architected Principles):**
  - **Operational Excellence:**  
    - Implement structured logging and detailed monitoring using CloudWatch, including correlation IDs for tracing requests and errors.
    - Use CloudFormation for infrastructure as code, ensuring consistent deployments and easy rollback if necessary.
  - **Security:**  
    - Enforce API key authentication and enable AWS IAM roles and policies following the principle of least privilege.
    - Validate inputs at both the API Gateway (using request validators) and the Lambda function to prevent injection attacks.
  - **Reliability:**  
    - Integrate API Gateway’s throttling and usage plans to prevent abuse and ensure service reliability during traffic spikes.
    - Implement robust error handling and retry mechanisms within the Lambda function.
  - **Performance Efficiency:**  
    - Use mapping templates to ensure data consistency and minimize transformation overhead.
    - Consider API Gateway HTTP APIs if they meet performance requirements, as they offer lower latency and cost benefits for certain workloads.
  - **Cost Optimization:**  
    - Monitor API usage and set appropriate throttling limits to manage costs effectively.
    - Leverage AWS managed services (API Gateway, Lambda, CloudWatch) that scale automatically based on demand, reducing the need for over-provisioning.

### US-305: File Upload with Presigned S3 URLs

**As a** user of the Hello World API,  
**I want to** securely upload files to S3 using presigned URLs,  
**So that** I can share files without needing direct S3 access credentials.

**Acceptance Criteria:**
- API provides an endpoint to request a presigned S3 URL for file uploads
- Presigned URLs are time-limited for security (e.g., expire after 15 minutes)
- File uploads are restricted by size and file type
- Uploaded files are stored in a secure, properly configured S3 bucket
- API key authentication is required to request presigned URLs

**Implementation Details:**
- Create a new API Gateway endpoint for requesting presigned URLs
- Implement Lambda function to generate presigned S3 URLs using boto3
- Configure S3 bucket with appropriate security settings and lifecycle policies
- Add validation for file size and type before generating presigned URLs
- Implement logging for all presigned URL requests and successful uploads
- Update CloudFormation template to include S3 bucket and necessary IAM permissions

### US-306: Metadata Storage for Uploaded Files

**As an** administrator of the Hello World API,  
**I want to** maintain metadata about uploaded files,  
**So that** I can track usage patterns and manage file lifecycle.

**Acceptance Criteria:**
- Each file upload is recorded with metadata (filename, size, upload time, user identifier)
- Metadata is stored in a DynamoDB table for efficient querying
- API provides endpoints to query file metadata with filtering options
- Automatic cleanup of expired or unused files based on metadata

**Implementation Details:**
- Create DynamoDB table via CloudFormation for storing file metadata
- Enhance Lambda function to record metadata upon successful file uploads
- Implement query functionality for metadata retrieval
- Create scheduled Lambda function for cleanup of expired files
- Add appropriate IAM permissions for DynamoDB and S3 operations

## Recommendations for Future Alignment

1. **Documentation Synchronization**
   - Update user stories whenever new features are implemented
   - Include user story IDs in commit messages for traceability
   - Review user stories during sprint planning and retrospectives

2. **Code and Documentation Alignment**
   - Implement a documentation review step in the CI/CD pipeline
   - Use automated tools to detect discrepancies between code and documentation
   - Schedule regular documentation maintenance sprints

3. **End-to-End Traceability**
   - Create a traceability matrix linking user stories to code implementations
   - Include references to user stories in code comments
   - Tag GitHub issues with corresponding user story IDs