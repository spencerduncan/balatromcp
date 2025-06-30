#!/bin/bash

# BalatroMCP MCP Server Startup Script
# Handles installation, building, and running the MCP server with proper error checking

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🚀 BalatroMCP MCP Server Startup${NC}"
echo "Script location: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"
echo

# Function to print status messages
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists node; then
        print_error "Node.js is not installed. Please install Node.js 18+ first."
        echo "Download from: https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Please upgrade to Node.js 18+."
        exit 1
    fi
    
    if ! command_exists npm; then
        print_error "npm is not installed. Please install npm."
        exit 1
    fi
    
    print_success "Prerequisites check passed (Node.js v$(node --version), npm v$(npm --version))"
}

# Setup function
setup_mcp_server() {
    print_status "Setting up MCP server..."
    
    # Change to MCP server directory
    cd "$SCRIPT_DIR"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        print_error "package.json not found in $SCRIPT_DIR"
        print_error "Are you running this script from the correct directory?"
        exit 1
    fi
    
    # Install dependencies if node_modules doesn't exist or package-lock.json is newer
    if [ ! -d "node_modules" ] || [ "package-lock.json" -nt "node_modules" ]; then
        print_status "Installing dependencies..."
        npm install
        print_success "Dependencies installed"
    else
        print_status "Dependencies already installed"
    fi
    
    # Build TypeScript
    print_status "Building TypeScript..."
    npm run build
    print_success "TypeScript compiled successfully"
    
    # Verify dist directory exists
    if [ ! -d "dist" ] || [ ! -f "dist/index.js" ]; then
        print_error "Build failed - dist/index.js not found"
        exit 1
    fi
}

# Run tests
run_tests() {
    print_status "Running tests to verify functionality..."
    
    if npm test; then
        print_success "All tests passed ✅"
    else
        print_warning "Some tests failed, but continuing anyway..."
        print_warning "Check test output above for details"
    fi
}

# Check for Balatro integration
check_balatro_integration() {
    print_status "Checking Balatro integration..."
    
    SHARED_DIR="$PROJECT_ROOT/shared"
    if [ -d "$SHARED_DIR" ]; then
        print_success "Shared directory found: $SHARED_DIR"
        
        # List shared files if they exist
        if ls "$SHARED_DIR"/*.json >/dev/null 2>&1; then
            print_status "Available shared files:"
            ls -la "$SHARED_DIR"/*.json | while read line; do
                echo "  $line"
            done
        else
            print_warning "No JSON files found in shared directory"
            print_warning "Make sure Balatro with BalatroMCP mod is running"
        fi
    else
        print_warning "Shared directory not found: $SHARED_DIR"
        print_warning "The shared directory will be created when Balatro with BalatroMCP mod starts"
    fi
}

# Start the MCP server
start_server() {
    print_status "Starting BalatroMCP MCP Server..."
    echo
    print_success "🎮 MCP Server is now running!"
    print_status "Configure Claude Desktop with this server path:"
    echo -e "${YELLOW}$SCRIPT_DIR/dist/index.js${NC}"
    echo
    print_status "Environment variables:"
    echo "  SHARED_DIR=${SHARED_DIR:-$PROJECT_ROOT/shared}"
    echo
    print_status "Press Ctrl+C to stop the server"
    echo
    
    # Set environment variable for shared directory if not already set
    export SHARED_DIR="${SHARED_DIR:-$PROJECT_ROOT/shared}"
    
    # Start the server
    node dist/index.js
}

# Integration test function
run_integration_test() {
    print_status "Running integration test..."
    
    if node dist/integration-test.js; then
        print_success "Integration test passed ✅"
    else
        print_warning "Integration test failed, but server should still work"
    fi
}

# Main execution flow
main() {
    # Parse command line arguments
    RUN_TESTS=true
    RUN_INTEGRATION=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-tests)
                RUN_TESTS=false
                shift
                ;;
            --no-integration)
                RUN_INTEGRATION=false
                shift
                ;;
            --help|-h)
                echo "BalatroMCP MCP Server Startup Script"
                echo
                echo "Usage: $0 [options]"
                echo
                echo "Options:"
                echo "  --no-tests         Skip running unit tests"
                echo "  --no-integration   Skip running integration test"
                echo "  --help, -h         Show this help message"
                echo
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Execute setup steps
    check_prerequisites
    setup_mcp_server
    
    if [ "$RUN_TESTS" = true ]; then
        run_tests
    fi
    
    if [ "$RUN_INTEGRATION" = true ]; then
        run_integration_test
    fi
    
    check_balatro_integration
    
    # Start the server (this will run indefinitely)
    start_server
}

# Handle Ctrl+C gracefully
trap 'echo; print_status "Shutting down MCP server..."; exit 0' INT TERM

# Run main function
main "$@"