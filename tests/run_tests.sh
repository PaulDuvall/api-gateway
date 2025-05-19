#!/bin/bash

# Hello World API Test Runner Script
# This script runs all tests for the Hello World API project

set -e

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_GATEWAY_DIR="$(dirname "$SCRIPT_DIR")"
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

# Setup virtual environment if needed
setup_environment() {
    print_section "Setting up test environment"
    
    # Find Python command
    if command -v python3.11 &> /dev/null; then
        PYTHON_CMD="python3.11"
    elif command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python not found. Please install Python 3.x"
        exit 1
    fi
    
    print_success "Using Python command: $PYTHON_CMD"
    
    # Create virtual environment if it doesn't exist
    if [ ! -d "$API_GATEWAY_DIR/venv" ]; then
        $PYTHON_CMD -m venv "$API_GATEWAY_DIR/venv"
    fi
    
    # Activate virtual environment
    source "$API_GATEWAY_DIR/venv/bin/activate"
    print_success "Activating virtual environment"
    
    # Install test dependencies
    print_warning "Installing test dependencies"
    pip install pytest pytest-cov moto boto3 requests docker openapi_spec_validator
    print_success "Test dependencies installed"
    
    # Create test directories if they don't exist
    mkdir -p "$SCRIPT_DIR/unit"
    mkdir -p "$SCRIPT_DIR/api"
}

# Run unit tests
run_unit_tests() {
    print_section "Running unit tests"
    
    # Run pytest without coverage report
    cd "$API_GATEWAY_DIR"
    python -m pytest -xvs "$SCRIPT_DIR/unit"
    
    if [ $? -eq 0 ]; then
        print_success "Unit tests passed successfully"
    else
        print_error "Unit tests failed"
    fi
}

# Run API tests against local or deployed environment
run_api_tests() {
    print_section "Running API tests"
    
    # Check if we have a deployed API to test against
    cd "$API_GATEWAY_DIR"
    if [ -d "$SCRIPT_DIR/api" ]; then
        python -m pytest -xvs "$SCRIPT_DIR/api"
        
        if [ $? -eq 0 ]; then
            print_success "API tests passed successfully"
        else
            print_error "API tests failed"
        fi
    else
        print_warning "No API tests found. Skipping."
    fi
}

# Main function
main() {
    # Setup test environment
    setup_environment
    
    # Check if specific test type is requested
    if [ $# -gt 0 ]; then
        if [ "$1" == "unit" ]; then
            run_unit_tests
        elif [ "$1" == "api" ]; then
            run_api_tests
        else
            # Run all tests by default
            run_unit_tests
            run_api_tests
        fi
    else
        # Run all tests by default
        run_unit_tests
        run_api_tests
    fi
    print_section "All tests completed successfully!"
}

# Execute main function with all arguments
main "$@"
