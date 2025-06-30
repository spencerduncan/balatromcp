# BalatroMCP MCP Server Startup Script (PowerShell)
# Handles installation, building, and running the MCP server with proper error checking

param(
    [switch]$NoTests,
    [switch]$NoIntegration,
    [switch]$Help
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green" 
    Yellow = "Yellow"
    Blue = "Blue"
    Gray = "Gray"
}

# Script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red
}

function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Show-Help {
    Write-Host "BalatroMCP MCP Server Startup Script" -ForegroundColor $Colors.Blue
    Write-Host ""
    Write-Host "Usage: .\start-mcp-server.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -NoTests         Skip running unit tests"
    Write-Host "  -NoIntegration   Skip running integration test"  
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\start-mcp-server.ps1                    # Full startup with tests"
    Write-Host "  .\start-mcp-server.ps1 -NoTests           # Skip unit tests"
    Write-Host "  .\start-mcp-server.ps1 -NoTests -NoIntegration  # Quick start"
}

function Test-Prerequisites {
    Write-Status "Checking prerequisites..."
    
    if (-not (Test-Command "node")) {
        Write-Error "Node.js is not installed. Please install Node.js 18+ first."
        Write-Host "Download from: https://nodejs.org/" -ForegroundColor $Colors.Yellow
        exit 1
    }
    
    $nodeVersion = (node --version) -replace 'v', ''
    $nodeMajor = [int]($nodeVersion -split '\.')[0]
    
    if ($nodeMajor -lt 18) {
        Write-Error "Node.js version $nodeVersion is too old. Please upgrade to Node.js 18+."
        exit 1
    }
    
    if (-not (Test-Command "npm")) {
        Write-Error "npm is not installed. Please install npm."
        exit 1
    }
    
    $npmVersion = npm --version
    Write-Success "Prerequisites check passed (Node.js v$(node --version), npm v$npmVersion)"
}

function Initialize-McpServer {
    Write-Status "Setting up MCP server..."
    
    # Change to MCP server directory
    Set-Location $ScriptDir
    
    # Check if package.json exists
    if (-not (Test-Path "package.json")) {
        Write-Error "package.json not found in $ScriptDir"
        Write-Error "Are you running this script from the correct directory?"
        exit 1
    }
    
    # Install dependencies if needed
    $needsInstall = (-not (Test-Path "node_modules")) -or 
                   ((Get-Item "package-lock.json" -ErrorAction SilentlyContinue).LastWriteTime -gt 
                    (Get-Item "node_modules" -ErrorAction SilentlyContinue).LastWriteTime)
    
    if ($needsInstall) {
        Write-Status "Installing dependencies..."
        npm install
        if ($LASTEXITCODE -ne 0) {
            Write-Error "npm install failed"
            exit 1
        }
        Write-Success "Dependencies installed"
    } else {
        Write-Status "Dependencies already installed"
    }
    
    # Build TypeScript
    Write-Status "Building TypeScript..."
    npm run build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "TypeScript build failed"
        exit 1
    }
    Write-Success "TypeScript compiled successfully"
    
    # Verify dist directory exists
    if (-not (Test-Path "dist\index.js")) {
        Write-Error "Build failed - dist\index.js not found"
        exit 1
    }
}

function Invoke-Tests {
    Write-Status "Running tests to verify functionality..."
    
    npm test
    if ($LASTEXITCODE -eq 0) {
        Write-Success "All tests passed ✅"
        return $true
    } else {
        Write-Warning "Some tests failed, but continuing anyway..."
        Write-Warning "Check test output above for details"
        return $false
    }
}

function Invoke-IntegrationTest {
    Write-Status "Running integration test..."
    
    node dist/integration-test.js
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Integration test passed ✅"
        return $true
    } else {
        Write-Warning "Integration test failed, but server should still work"
        return $false
    }
}

function Test-BalatroIntegration {
    Write-Status "Checking Balatro integration..."
    
    $SharedDir = Join-Path $ProjectRoot "shared"
    
    if (Test-Path $SharedDir) {
        Write-Success "Shared directory found: $SharedDir"
        
        $jsonFiles = Get-ChildItem -Path $SharedDir -Filter "*.json" -ErrorAction SilentlyContinue
        if ($jsonFiles) {
            Write-Status "Available shared files:"
            $jsonFiles | ForEach-Object {
                Write-Host "  $($_.FullName)" -ForegroundColor $Colors.Gray
            }
        } else {
            Write-Warning "No JSON files found in shared directory"
            Write-Warning "Make sure Balatro with BalatroMCP mod is running"
        }
    } else {
        Write-Warning "Shared directory not found: $SharedDir"
        Write-Warning "The shared directory will be created when Balatro with BalatroMCP mod starts"
    }
}

function Start-McpServer {
    Write-Status "Starting BalatroMCP MCP Server..."
    Write-Host ""
    Write-Success "🎮 MCP Server is now running!"
    Write-Status "Configure Claude Desktop with this server path:"
    Write-Host "$ScriptDir\dist\index.js" -ForegroundColor $Colors.Yellow
    Write-Host ""
    Write-Status "Environment variables:"
    $sharedDir = if ($env:SHARED_DIR) { $env:SHARED_DIR } else { Join-Path $ProjectRoot "shared" }
    Write-Host "  SHARED_DIR=$sharedDir"
    Write-Host ""
    Write-Status "Press Ctrl+C to stop the server"
    Write-Host ""
    
    # Set environment variable for shared directory if not already set
    if (-not $env:SHARED_DIR) {
        $env:SHARED_DIR = Join-Path $ProjectRoot "shared"
    }
    
    # Start the server
    try {
        node dist/index.js
    } catch {
        Write-Error "Failed to start MCP server: $($_.Exception.Message)"
        exit 1
    }
}

function Main {
    # Show help if requested
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Host "🚀 BalatroMCP MCP Server Startup" -ForegroundColor $Colors.Blue
    Write-Host "Script location: $ScriptDir"
    Write-Host "Project root: $ProjectRoot"
    Write-Host ""
    
    # Execute setup steps
    Test-Prerequisites
    Initialize-McpServer
    
    if (-not $NoTests) {
        Invoke-Tests | Out-Null
    }
    
    if (-not $NoIntegration) {
        Invoke-IntegrationTest | Out-Null
    }
    
    Test-BalatroIntegration
    
    # Start the server (this will run indefinitely)
    Start-McpServer
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent PowerShell.Exiting -Action {
    Write-Host ""
    Write-Status "Shutting down MCP server..."
}

# Check execution policy
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq "Restricted") {
    Write-Warning "PowerShell execution policy is Restricted."
    Write-Warning "Run this command to allow script execution:"
    Write-Host "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor $Colors.Yellow
    Write-Warning "Or run with: powershell -ExecutionPolicy Bypass -File start-mcp-server.ps1"
    exit 1
}

# Run main function
Main