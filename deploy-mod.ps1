#!/usr/bin/env pwsh
# Deploy BalatroMCP mod to Balatro mod directory
# Copies all mod files excluding tests and documentation

param(
    [switch]$Force,
    [switch]$Verbose
)

# Define source and destination paths
$SourcePath = $PSScriptRoot
$DestinationPath = "$env:APPDATA\Balatro\mods\BalatroMCP"

# Files and directories to include
$IncludeFiles = @(
    "action_executor.lua",
    "BalatroMCP.lua", 
    "joker_manager.lua",
    "manifest.json",
    "message_manager.lua",
    "state_extractor.lua"
)

$IncludeDirectories = @(
    "compatibility",
    "interfaces", 
    "transports"
)

# Specific files to include from libs (excluding test libraries)
$LibsFiles = @(
    "json.lua"
)

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    if ($Verbose) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Copy-ModFiles {
    Write-Host "Deploying BalatroMCP mod to: $DestinationPath" -ForegroundColor Green
    
    # Create destination directory if it doesn't exist
    if (-not (Test-Path $DestinationPath)) {
        Write-Status "Creating destination directory: $DestinationPath" "Yellow"
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    # Copy root level files
    Write-Status "Copying root level files..." "Cyan"
    foreach ($file in $IncludeFiles) {
        $_sourcePath = Join-Path $SourcePath $file
        $destPath = Join-Path $DestinationPath $file
        
        if (Test-Path $_sourcePath) {
            Write-Status "  Copying: $file" "White"
            Copy-Item $_sourcePath $destPath -Force
        } else {
            Write-Warning "Source file not found: $file"
        }
    }
    
    # Copy directory structures
    Write-Status "Copying directories..." "Cyan"
    foreach ($dir in $IncludeDirectories) {
        $sourceDir = Join-Path $SourcePath $dir
        $destDir = Join-Path $DestinationPath $dir
        
        if (Test-Path $sourceDir) {
            Write-Status "  Copying directory: $dir" "White"
            # Create destination directory
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            # Copy all files from source directory
            Copy-Item "$sourceDir\*" $destDir -Recurse -Force
        } else {
            Write-Warning "Source directory not found: $dir"
        }
    }
    
    # Copy specific libs files (excluding test libraries)
    Write-Status "Copying libs files..." "Cyan"
    $libsSourceDir = Join-Path $SourcePath "libs"
    $libsDestDir = Join-Path $DestinationPath "libs"
    
    if (Test-Path $libsSourceDir) {
        # Create libs directory
        if (-not (Test-Path $libsDestDir)) {
            New-Item -ItemType Directory -Path $libsDestDir -Force | Out-Null
        }
        
        foreach ($libFile in $LibsFiles) {
            $sourceLibPath = Join-Path $libsSourceDir $libFile
            $destLibPath = Join-Path $libsDestDir $libFile
            
            if (Test-Path $sourceLibPath) {
                Write-Status "  Copying: libs\$libFile" "White"
                Copy-Item $sourceLibPath $destLibPath -Force
            } else {
                Write-Warning "Libs file not found: $libFile"
            }
        }
    }
    
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host "Mod files copied to: $DestinationPath" -ForegroundColor Green
}

function Show-Help {
    Write-Host "BalatroMCP Mod Deployment Script" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\deploy-mod.ps1 [-Force] [-Verbose]" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -Force     Overwrite existing files without confirmation" -ForegroundColor White
    Write-Host "  -Verbose   Show detailed output during deployment" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\deploy-mod.ps1                 # Basic deployment" -ForegroundColor White
    Write-Host "  .\deploy-mod.ps1 -Verbose        # Verbose deployment" -ForegroundColor White
    Write-Host "  .\deploy-mod.ps1 -Force -Verbose # Force overwrite with verbose output" -ForegroundColor White
}

# Main execution
try {
    if ($args -contains "-help" -or $args -contains "--help" -or $args -contains "-h") {
        Show-Help
        exit 0
    }
    
    # Verify source directory exists
    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source directory not found: $SourcePath"
        exit 1
    }
    
    # Check if destination exists and prompt if not using -Force
    if ((Test-Path $DestinationPath) -and -not $Force) {
        $response = Read-Host "Destination directory exists. Overwrite? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-Host "Deployment cancelled." -ForegroundColor Yellow
            exit 0
        }
    }
    
    Copy-ModFiles
    
} catch {
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}