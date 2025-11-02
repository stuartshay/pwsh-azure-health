#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Retrieves Azure Function App keys and saves them locally.

.DESCRIPTION
    Downloads function keys from Azure Function App and saves them to .keys directory
    for local development use. The .keys directory is excluded from git to prevent
    accidentally committing sensitive keys.

.PARAMETER ResourceGroup
    Azure resource group name. Defaults to rg-azure-health-dev.

.PARAMETER FunctionAppName
    Azure Function App name. If not provided, will auto-discover from resource group.

.PARAMETER Environment
    Environment name (dev, prod). Defaults to dev.

.PARAMETER OutputDirectory
    Directory to save keys. Defaults to .keys in repository root.

.EXAMPLE
    ./get-function-keys.ps1

.EXAMPLE
    ./get-function-keys.ps1 -Environment prod

.EXAMPLE
    ./get-function-keys.ps1 -ResourceGroup rg-azure-health-prod -FunctionAppName my-function-app
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup,

    [Parameter()]
    [string]$FunctionAppName,

    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'

# Colors for output
$script:Green = "`e[32m"
$script:Yellow = "`e[33m"
$script:Red = "`e[31m"
$script:Blue = "`e[34m"
$script:Reset = "`e[0m"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $script:Reset
    )
    Write-Host "${Color}${Message}${script:Reset}"
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-ColorOutput "========================================" $script:Blue
    Write-ColorOutput $Message $script:Blue
    Write-ColorOutput "========================================" $script:Blue
    Write-Host ""
}

# Determine repository root
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot ".keys"
}

# Set default resource group if not provided
if (-not $ResourceGroup) {
    $ResourceGroup = "rg-azure-health-$Environment"
}

Write-Header "Azure Function Keys Retrieval"

Write-ColorOutput "Configuration:" $script:Yellow
Write-Host "  Environment:     $Environment"
Write-Host "  Resource Group:  $ResourceGroup"
Write-Host "  Output Dir:      $OutputDirectory"
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-ColorOutput "✓ Azure CLI detected (version: $($azVersion.'azure-cli'))" $script:Green
}
catch {
    Write-ColorOutput "✗ Azure CLI not found. Please install Azure CLI first." $script:Red
    Write-Host "  Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in
Write-Host ""
Write-ColorOutput "Checking Azure authentication..." $script:Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    Write-ColorOutput "✓ Logged in as: $($account.user.name)" $script:Green
    Write-Host "  Subscription: $($account.name)"
}
catch {
    Write-ColorOutput "✗ Not logged in to Azure. Please run 'az login' first." $script:Red
    exit 1
}

# Auto-discover Function App if not provided
if (-not $FunctionAppName) {
    Write-Host ""
    Write-ColorOutput "Discovering Function App in resource group..." $script:Yellow

    $functionApps = az functionapp list --resource-group $ResourceGroup --output json | ConvertFrom-Json

    if (-not $functionApps -or $functionApps.Count -eq 0) {
        Write-ColorOutput "✗ No Function Apps found in resource group: $ResourceGroup" $script:Red
        exit 1
    }

    $FunctionAppName = $functionApps[0].name
    Write-ColorOutput "✓ Found Function App: $FunctionAppName" $script:Green
}

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-ColorOutput "✓ Created directory: $OutputDirectory" $script:Green
}

Write-Host ""
Write-Header "Retrieving Function Keys"

# Get host keys (master keys)
Write-ColorOutput "Retrieving host keys..." $script:Yellow
try {
    $hostKeys = az functionapp keys list `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --output json | ConvertFrom-Json

    Write-ColorOutput "✓ Retrieved host keys" $script:Green

    # Save master key
    if ($hostKeys.masterKey) {
        $masterKeyFile = Join-Path $OutputDirectory "master.key"
        $hostKeys.masterKey | Out-File -FilePath $masterKeyFile -NoNewline -Encoding utf8
        Write-Host "  → Saved master key to: $masterKeyFile"
    }

    # Save default function key
    if ($hostKeys.functionKeys.default) {
        $defaultKeyFile = Join-Path $OutputDirectory "default.key"
        $hostKeys.functionKeys.default | Out-File -FilePath $defaultKeyFile -NoNewline -Encoding utf8
        Write-Host "  → Saved default key to: $defaultKeyFile"
    }

    # Save all named function keys
    if ($hostKeys.functionKeys.PSObject.Properties.Name.Count -gt 1) {
        foreach ($keyName in $hostKeys.functionKeys.PSObject.Properties.Name) {
            if ($keyName -ne 'default') {
                $keyValue = $hostKeys.functionKeys.$keyName
                $keyFile = Join-Path $OutputDirectory "$keyName.key"
                $keyValue | Out-File -FilePath $keyFile -NoNewline -Encoding utf8
                Write-Host "  → Saved $keyName key to: $keyFile"
            }
        }
    }

}
catch {
    Write-ColorOutput "✗ Failed to retrieve function keys: $_" $script:Red
    exit 1
}

# Create a summary file with key information
Write-Host ""
Write-ColorOutput "Creating summary file..." $script:Yellow

$summaryFile = Join-Path $OutputDirectory "keys-info.txt"
$functionUrl = "https://$FunctionAppName.azurewebsites.net"

$summary = @"
Azure Function Keys Summary
===========================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Function App: $FunctionAppName
Resource Group: $ResourceGroup
Environment: $Environment
Function URL: $functionUrl

Available Keys:
"@

# List all key files
Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    $keyName = $_.BaseName
    $summary += "`n  - $keyName ($($_.Name))"
}

$summary += @"


Usage Examples:
===============

1. Using default function key (query parameter):
   curl "$functionUrl/api/GetServiceHealth?code=`$(cat .keys/default.key)"

2. Using function key (header):
   curl -H "x-functions-key: `$(cat .keys/default.key)" $functionUrl/api/GetServiceHealth

3. PowerShell with function key:
   `$key = Get-Content .keys/default.key -Raw
   `$headers = @{ "x-functions-key" = `$key }
   Invoke-RestMethod -Uri "$functionUrl/api/GetServiceHealth" -Headers `$headers

4. Test health endpoint (no auth required):
   curl $functionUrl/api/health

Security Notes:
===============
- Keys are saved in .keys/ directory
- This directory is excluded from git (.gitignore)
- Never commit keys to source control
- Rotate keys regularly for security
- Use master key only for administrative tasks
- Use function keys for API access

Key Files:
==========
"@

Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    $summary += "`n  $($_.FullName)"
}

$summary | Out-File -FilePath $summaryFile -Encoding utf8
Write-ColorOutput "✓ Saved summary to: $summaryFile" $script:Green

Write-Host ""
Write-Header "Success!"

Write-ColorOutput "Function keys have been downloaded and saved to:" $script:Green
Write-Host "  $OutputDirectory"
Write-Host ""
Write-ColorOutput "Key files:" $script:Yellow
Get-ChildItem -Path $OutputDirectory -Filter "*.key" | ForEach-Object {
    Write-Host "  • $($_.Name)"
}
Write-Host ""
Write-ColorOutput "📖 See $summaryFile for usage examples" $script:Blue
Write-Host ""
Write-ColorOutput "⚠️  Remember: Never commit these keys to git!" $script:Red
Write-Host ""
