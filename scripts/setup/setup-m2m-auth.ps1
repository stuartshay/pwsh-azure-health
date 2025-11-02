#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up Azure AD application registration for machine-to-machine (M2M) authentication.

.DESCRIPTION
    Creates an Azure AD app registration and service principal for automated
    access to the Azure Function App API. Generates client credentials and
    saves them securely to .keys directory.

.PARAMETER AppName
    Name for the Azure AD app registration. Defaults to pwsh-azure-health-client.

.PARAMETER Environment
    Environment (dev, prod). Defaults to dev.

.PARAMETER OutputDirectory
    Directory to save credentials. Defaults to .keys in repository root.

.EXAMPLE
    ./setup-m2m-auth.ps1

.EXAMPLE
    ./setup-m2m-auth.ps1 -AppName "monitoring-service" -Environment prod
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$AppName = "pwsh-azure-health-client",

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
$script:Cyan = "`e[36m"
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
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot ".keys"
}

Write-Header "Azure AD M2M Authentication Setup"

Write-ColorOutput "Configuration:" $script:Yellow
Write-Host "  App Name:    $AppName"
Write-Host "  Environment: $Environment"
Write-Host "  Output Dir:  $OutputDirectory"
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-ColorOutput "✓ Azure CLI detected (version: $($azVersion.'azure-cli'))" $script:Green
}
catch {
    Write-ColorOutput "✗ Azure CLI not found. Please install Azure CLI first." $script:Red
    exit 1
}

# Check if logged in
Write-Host ""
Write-ColorOutput "Checking Azure authentication..." $script:Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    $tenantId = $account.tenantId
    $subscriptionId = $account.id
    Write-ColorOutput "✓ Logged in as: $($account.user.name)" $script:Green
    Write-Host "  Subscription: $($account.name)"
    Write-Host "  Tenant ID: $tenantId"
}
catch {
    Write-ColorOutput "✗ Not logged in to Azure. Please run 'az login' first." $script:Red
    exit 1
}

Write-Host ""
Write-Header "Step 1: Create App Registration"

Write-ColorOutput "Creating Azure AD app registration..." $script:Yellow

try {
    # Check if app already exists
    $existingApp = az ad app list --display-name $AppName --output json | ConvertFrom-Json

    if ($existingApp -and $existingApp.Count -gt 0) {
        Write-ColorOutput "⚠  App registration already exists: $AppName" $script:Yellow
        $appId = $existingApp[0].appId
        Write-Host "  Using existing App ID: $appId"
    }
    else {
        # Create new app registration
        $app = az ad app create `
            --display-name $AppName `
            --sign-in-audience AzureADMyOrg `
            --output json | ConvertFrom-Json

        $appId = $app.appId
        Write-ColorOutput "✓ Created app registration: $AppName" $script:Green
        Write-Host "  App ID: $appId"
    }
}
catch {
    Write-ColorOutput "✗ Failed to create app registration: $_" $script:Red
    exit 1
}

Write-Host ""
Write-Header "Step 2: Create Service Principal"

try {
    # Check if service principal exists
    $existingSp = az ad sp show --id $appId --output json 2>$null | ConvertFrom-Json

    if ($existingSp) {
        Write-ColorOutput "⚠  Service principal already exists" $script:Yellow
        Write-Host "  Object ID: $($existingSp.id)"
    }
    else {
        $sp = az ad sp create --id $appId --output json | ConvertFrom-Json
        Write-ColorOutput "✓ Created service principal" $script:Green
        Write-Host "  Object ID: $($sp.id)"
    }
}
catch {
    Write-ColorOutput "✗ Failed to create service principal: $_" $script:Red
    exit 1
}

Write-Host ""
Write-Header "Step 3: Generate Client Secret"

Write-ColorOutput "Generating client secret..." $script:Yellow

try {
    # Create a new credential with 1 year expiration
    $credential = az ad app credential reset `
        --id $appId `
        --years 1 `
        --output json | ConvertFrom-Json

    $clientSecret = $credential.password
    Write-ColorOutput "✓ Client secret generated (expires in 1 year)" $script:Green
}
catch {
    Write-ColorOutput "✗ Failed to generate client secret: $_" $script:Red
    exit 1
}

Write-Host ""
Write-Header "Step 4: Save Credentials"

# Create output directory if needed
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

# Save credentials to files
$clientIdFile = Join-Path $OutputDirectory "m2m-client-id.txt"
$clientSecretFile = Join-Path $OutputDirectory "m2m-client-secret.key"
$tenantIdFile = Join-Path $OutputDirectory "m2m-tenant-id.txt"

$appId | Out-File -FilePath $clientIdFile -NoNewline -Encoding utf8
$clientSecret | Out-File -FilePath $clientSecretFile -NoNewline -Encoding utf8
$tenantId | Out-File -FilePath $tenantIdFile -NoNewline -Encoding utf8

Write-ColorOutput "✓ Saved credentials to .keys directory" $script:Green
Write-Host "  Client ID: $clientIdFile"
Write-Host "  Client Secret: $clientSecretFile"
Write-Host "  Tenant ID: $tenantIdFile"

# Create summary file
$summaryFile = Join-Path $OutputDirectory "m2m-auth-info.txt"

$summary = @"
Azure AD M2M Authentication Configuration
==========================================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

App Registration: $AppName
App ID (Client ID): $appId
Tenant ID: $tenantId
Subscription ID: $subscriptionId

Credential Files:
  Client ID: $clientIdFile
  Client Secret: $clientSecretFile (expires in 1 year)
  Tenant ID: $tenantIdFile

Usage:
======

1. Get Access Token (PowerShell):
   `$clientId = Get-Content $clientIdFile -Raw
   `$clientSecret = Get-Content $clientSecretFile -Raw
   `$tenantId = Get-Content $tenantIdFile -Raw
   `$resource = "https://<function-app-name>.azurewebsites.net"

   `$body = @{
       client_id     = `$clientId
       client_secret = `$clientSecret
       scope         = "`$resource/.default"
       grant_type    = "client_credentials"
   }

   `$token = (Invoke-RestMethod -Uri "https://login.microsoftonline.com/`$tenantId/oauth2/v2.0/token" -Method Post -Body `$body).access_token

2. Use Token to Call API:
   `$headers = @{ "Authorization" = "Bearer `$token" }
   Invoke-RestMethod -Uri "https://<function-app-name>.azurewebsites.net/api/GetServiceHealth" -Headers `$headers

3. Using the helper script:
   pwsh scripts/local/get-m2m-token.ps1

Security Notes:
===============
- Client secret expires in 1 year - rotate before expiration
- Store credentials securely - they are saved in .keys/ (excluded from git)
- Never commit these files to source control
- Use Azure Key Vault for production secrets
- Consider using Managed Identity for Azure-to-Azure scenarios

Next Steps:
===========
1. Configure Easy Auth identity provider in Bicep (if needed)
2. Use 'scripts/local/get-m2m-token.ps1' to generate tokens
3. Test API access with generated tokens
"@

$summary | Out-File -FilePath $summaryFile -Encoding utf8

Write-Host ""
Write-Header "Setup Complete!"

Write-ColorOutput "M2M authentication configured successfully!" $script:Green
Write-Host ""
Write-ColorOutput "Credentials saved to:" $script:Yellow
Write-Host "  $OutputDirectory"
Write-Host ""
Write-ColorOutput "📖 See $summaryFile for usage instructions" $script:Blue
Write-Host ""
Write-ColorOutput "Next: Use 'pwsh scripts/local/get-m2m-token.ps1' to generate access tokens" $script:Cyan
Write-Host ""
Write-ColorOutput "⚠️  Important: Client secret expires in 1 year!" $script:Red
Write-Host ""
