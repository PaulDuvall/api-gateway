# Hello World API Testing Documentation

This directory contains automated tests for the Hello World API project. All tests in this directory are designed to be fully automated and can be executed without manual intervention.

## Test Structure

The test directory is organized as follows:

```
tests/
├── README.md           # This documentation file
├── run_tests.sh        # Main test execution script
├── unit/               # Unit tests for individual components
├── integration/        # Integration tests for component interactions
├── api/                # End-to-end API tests
└── coverage/           # Test coverage reports (generated during test execution)
```

## Test Execution

To run the tests, use the provided `run_tests.sh` script:

```bash
# Run all tests
./tests/run_tests.sh

# Run only unit tests
./tests/run_tests.sh unit

# Run only integration tests
./tests/run_tests.sh integration

# Run only API tests
./tests/run_tests.sh api

# Generate coverage report only
./tests/run_tests.sh coverage
```

## Test Coverage Requirements

The project aims to maintain the following test coverage metrics:

- **Unit Test Coverage**: Minimum 80% code coverage for all Lambda functions
- **Integration Test Coverage**: All API endpoints must have at least one integration test
- **API Test Coverage**: All public API endpoints must have end-to-end tests with various input scenarios

## Automated Test Generation Process

The automated tests for this project are generated using a combination of manual development and AI-assisted generation. The process follows these steps:

1. **User Story Analysis**: Each user story is analyzed to identify testable requirements
2. **Test Case Design**: Test cases are designed to cover all acceptance criteria
3. **Test Implementation**: Tests are implemented using pytest and appropriate mocking libraries
4. **Test Validation**: Generated tests are validated against the codebase to ensure accuracy
5. **Test Integration**: Tests are integrated into the CI/CD pipeline for automated execution

## Periodic Review

All tests should be reviewed on a quarterly basis to ensure they remain aligned with the evolving codebase. The review process includes:

1. Checking for outdated test assumptions
2. Updating tests to reflect new features or changed requirements
3. Removing tests for deprecated functionality
4. Enhancing test coverage for critical components

## Quality Control

The quality of the automated tests is maintained through:

- **Code Coverage Analysis**: Using pytest-cov to identify untested code paths
- **Manual Code Reviews**: All test code undergoes peer review before merging
- **Test Failure Analysis**: Failed tests are promptly investigated and fixed
- **Test Performance Monitoring**: Tests are optimized to run efficiently

## Traceability

All automated tests must be traceable to their corresponding user stories and requirements. This traceability is maintained in the following ways:

1. Test files include references to relevant user story IDs in their docstrings
2. The traceability matrix in `/api_gateway/docs/traceability_matrix.md` links user stories to test files
3. Test reports include mappings between test results and user stories

## Maintenance

### Running Tests

Tests can be run locally during development or automatically via the CI/CD pipeline. To run tests locally:

1. Ensure you have activated the Python virtual environment
2. Navigate to the project root directory
3. Run the test script as described in the "Test Execution" section

### Updating Tests

When updating tests, follow these guidelines:

1. Maintain backward compatibility where possible
2. Update test documentation when changing test behavior
3. Ensure all tests pass after making changes
4. Update the traceability matrix if test coverage changes

### Troubleshooting

Common test issues and their solutions:

- **Missing Dependencies**: Ensure all test dependencies are installed via `pip install -r requirements-dev.txt`
- **Environment Issues**: Verify that AWS credentials are properly configured for integration tests
- **Mocking Problems**: Check that all external services are properly mocked in unit tests
- **Timing Issues**: Add appropriate waits or retries for asynchronous operations

## Team Collaboration

The team should collaborate on test improvement through:

- Regular test review sessions
- Sharing test patterns and best practices
- Collectively addressing test failures
- Continuous refinement of the test generation process

## Comprehensive Testing Strategy

The project employs a multi-layered testing approach:

- **Unit Tests**: Test individual functions and classes in isolation
- **Integration Tests**: Test interactions between components
- **End-to-End Tests**: Test the complete API flow from request to response
- **Infrastructure Tests**: Validate CloudFormation templates and resource configurations

This comprehensive approach ensures that any consolidation or deletion of code does not impact functionality.

## PDF Hash Service Tests

The PDF Hash Service has its own set of tests to verify functionality:

### Unit Tests

- **`test_pdf_hash_service.py`**: Tests the core PDF generation, S3 operations, and hash computation functions
- **`test_pdf_hash_lambda.py`**: Tests the Lambda handler for the PDF hash API
- **`test_pdf_hash_client.py`**: Tests the client script that orchestrates the workflow

### Running PDF Hash Tests

To run all PDF hash-related tests:

```bash
python3 -m pytest tests/unit/test_pdf_hash_*.py -v
```

To run a specific test file:

```bash
python3 -m pytest tests/unit/test_pdf_hash_service.py -v
```

### End-to-End Testing

To test the complete PDF hash workflow from PDF generation to hash computation:

```bash
./run.sh test-pdf-hash
```

This command will:
1. Set up the necessary environment variables
2. Generate a test PDF
3. Upload it to S3 using a pre-signed URL
4. Call the PDF hash API endpoint
5. Verify the hash response

### Test Coverage

The PDF hash tests cover:

- PDF generation with various content
- S3 pre-signed URL creation
- S3 upload functionality
- PDF download from URL
- SHA-256 hash computation
- Error handling for various failure scenarios
- Dynamic S3 bucket naming
