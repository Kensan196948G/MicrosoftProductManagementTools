#!/bin/bash

# Microsoft 365 Management API Server Startup Script
# This script sets up the environment and starts the Node.js/Express server

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Node.js is installed
check_node() {
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed. Please install Node.js 18+ and try again."
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d 'v' -f 2 | cut -d '.' -f 1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18 or higher is required. Current version: $(node --version)"
        exit 1
    fi
    
    print_success "Node.js $(node --version) is installed"
}

# Check if npm is installed
check_npm() {
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install npm and try again."
        exit 1
    fi
    
    print_success "npm $(npm --version) is installed"
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    directories=("logs" "temp" "reports")
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_status "Created directory: $dir"
        fi
    done
    
    print_success "Directories created successfully"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    if [ ! -f "package.json" ]; then
        print_error "package.json not found. Please run this script from the backend directory."
        exit 1
    fi
    
    if [ ! -d "node_modules" ] || [ ! -f "package-lock.json" ]; then
        npm install
        print_success "Dependencies installed successfully"
    else
        print_status "Dependencies already installed, checking for updates..."
        npm ci
        print_success "Dependencies verified"
    fi
}

# Check environment configuration
check_environment() {
    print_status "Checking environment configuration..."
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            print_warning ".env file not found. Copying from .env.example"
            cp .env.example .env
            print_warning "Please edit .env file with your actual configuration before starting the server"
        else
            print_error ".env file not found and no .env.example available"
            exit 1
        fi
    fi
    
    # Check for required environment variables
    if [ -f ".env" ]; then
        source .env
        
        required_vars=("JWT_SECRET" "MS_TENANT_ID" "MS_CLIENT_ID" "MS_CLIENT_SECRET")
        missing_vars=()
        
        for var in "${required_vars[@]}"; do
            if [ -z "${!var}" ] || [ "${!var}" = "your-${var,,}" ] || [[ "${!var}" == *"change-this"* ]]; then
                missing_vars+=("$var")
            fi
        done
        
        if [ ${#missing_vars[@]} -gt 0 ]; then
            print_error "The following environment variables need to be configured:"
            for var in "${missing_vars[@]}"; do
                echo "  - $var"
            done
            print_error "Please edit the .env file with your actual values"
            exit 1
        fi
    fi
    
    print_success "Environment configuration verified"
}

# Check PowerShell availability (for Microsoft 365 integration)
check_powershell() {
    print_status "Checking PowerShell availability..."
    
    if command -v pwsh &> /dev/null; then
        print_success "PowerShell Core (pwsh) is available"
    elif command -v powershell &> /dev/null; then
        print_warning "PowerShell Core (pwsh) not found, but Windows PowerShell is available"
        print_warning "For better compatibility, consider installing PowerShell Core"
    else
        print_warning "PowerShell not found. Some Microsoft 365 features may not work properly"
        print_warning "Please install PowerShell Core for full functionality"
    fi
}

# Start the server
start_server() {
    print_status "Starting Microsoft 365 Management API server..."
    
    # Set NODE_ENV if not set
    export NODE_ENV=${NODE_ENV:-development}
    
    print_status "Environment: $NODE_ENV"
    print_status "Port: ${PORT:-3001}"
    
    if [ "$NODE_ENV" = "development" ]; then
        if command -v nodemon &> /dev/null; then
            print_status "Starting server with nodemon (development mode)..."
            npm run dev
        else
            print_warning "nodemon not found, starting with node..."
            npm start
        fi
    else
        print_status "Starting server in production mode..."
        npm start
    fi
}

# Cleanup function
cleanup() {
    print_status "Shutting down server..."
    # Kill any remaining processes
    pkill -f "node.*src/app.js" 2>/dev/null || true
    print_success "Server shutdown complete"
}

# Handle interruption signals
trap cleanup SIGINT SIGTERM

# Main execution
main() {
    echo ""
    echo "=================================================="
    echo "  Microsoft 365 Management API Server Startup   "
    echo "=================================================="
    echo ""
    
    # Change to script directory
    cd "$(dirname "$0")"
    
    # Run checks
    check_node
    check_npm
    check_powershell
    create_directories
    install_dependencies
    check_environment
    
    echo ""
    print_success "All pre-flight checks passed!"
    echo ""
    
    # Start the server
    start_server
}

# Run main function
main "$@"