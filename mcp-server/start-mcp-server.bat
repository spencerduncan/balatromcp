@echo off
REM BalatroMCP MCP Server Startup Script (Batch)
REM Simple wrapper for the PowerShell script

echo 🚀 BalatroMCP MCP Server Startup
echo.

REM Check if PowerShell is available
where powershell >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: PowerShell is not available
    echo Please install PowerShell or run the server manually:
    echo   cd %~dp0
    echo   npm install
    echo   npm run build  
    echo   npm start
    pause
    exit /b 1
)

REM Get the directory where this batch file is located
set SCRIPT_DIR=%~dp0

echo Starting MCP server with PowerShell...
echo.

REM Run the PowerShell script with bypass execution policy
powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%start-mcp-server.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: MCP server startup failed
    echo Check the output above for details
    pause
    exit /b %ERRORLEVEL%
)

pause