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
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information to surface script status updates without relying on Write-Host.
.PARAMETER Message
    Text to display.
.PARAMETER Color
    Optional color name applied when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Default', 'Blue', 'Cyan', 'Gray', 'Green', 'Red', 'Yellow')]
        [string]$Color = 'Default'
    )

    $prefix = ''
    $suffix = ''

    if ($PSStyle) {
        switch ($Color) {
            'Blue'   { $prefix = $PSStyle.Foreground.Blue }
            'Cyan'   { $prefix = $PSStyle.Foreground.Cyan }
            'Gray'   { $prefix = $PSStyle.Foreground.Gray }
            'Green'  { $prefix = $PSStyle.Foreground.Green }
            'Red'    { $prefix = $PSStyle.Foreground.Red }
            'Yellow' { $prefix = $PSStyle.Foreground.Yellow }
        }

        if ($prefix) {
            $suffix = $PSStyle.Reset
        }
    }

    Write-Information ("{0}{1}{2}" -f $prefix, $Message, $suffix)
}

<#
.SYNOPSIS
    Displays a formatted header block in script output.
.DESCRIPTION
    Emits a blank line, a colored separator, the supplied message, and another separator.
.PARAMETER Message
    Header text to display.
#>
function Write-Header {
    param([string]$Message)
    Write-Message ''
    Write-Message '========================================' -Color Blue
    Write-Message $Message -Color Blue
    Write-Message '========================================' -Color Blue
    Write-Message ''
}

# Determine repository root
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repoRoot ".keys"
}

Write-Header "Azure AD M2M Authentication Setup"

Write-Message 'Configuration:' -Color Yellow
Write-Message "  App Name:    $AppName"
Write-Message "  Environment: $Environment"
Write-Message "  Output Dir:  $OutputDirectory"
Write-Message ''

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Message "[OK] Azure CLI detected (version: $($azVersion.'azure-cli'))" -Color Green
}
catch {
    Write-Message '[ERROR] Azure CLI not found. Please install Azure CLI first.' -Color Red
    exit 1
}

# Check if logged in
Write-Message ''
Write-Message 'Checking Azure authentication...' -Color Yellow
try {
    $account = az account show --output json | ConvertFrom-Json
    $tenantId = $account.tenantId
    $subscriptionId = $account.id
    Write-Message "[OK] Logged in as: $($account.user.name)" -Color Green
    Write-Message "  Subscription: $($account.name)"
    Write-Message "  Tenant ID: $tenantId"
}
catch {
    Write-Message "[ERROR] Not logged in to Azure. Please run 'az login' first." -Color Red
    exit 1
}

Write-Message ''
Write-Header "Step 1: Create App Registration"

Write-Message 'Creating Azure AD app registration...' -Color Yellow

try {
    # Check if app already exists
    $existingApp = az ad app list --display-name $AppName --output json | ConvertFrom-Json

    if ($existingApp -and $existingApp.Count -gt 0) {
        Write-Message "[WARN] App registration already exists: $AppName" -Color Yellow
        $appId = $existingApp[0].appId
        Write-Message "  Using existing App ID: $appId"
    }
    else {
        # Create new app registration
        $app = az ad app create `
            --display-name $AppName `
            --sign-in-audience AzureADMyOrg `
            --output json | ConvertFrom-Json

        $appId = $app.appId
        Write-Message "[OK] Created app registration: $AppName" -Color Green
        Write-Message "  App ID: $appId"
    }
}
catch {
    Write-Message "[ERROR] Failed to create app registration: $_" -Color Red
    exit 1
}

Write-Message ''
Write-Header "Step 2: Create Service Principal"

try {
    # Check if service principal exists
    $existingSp = az ad sp show --id $appId --output json 2>$null | ConvertFrom-Json

    if ($existingSp) {
        Write-Message '[WARN] Service principal already exists' -Color Yellow
        Write-Message "  Object ID: $($existingSp.id)"
    }
    else {
        $sp = az ad sp create --id $appId --output json | ConvertFrom-Json
        Write-Message '[OK] Created service principal' -Color Green
        Write-Message "  Object ID: $($sp.id)"
    }
}
catch {
    Write-Message "[ERROR] Failed to create service principal: $_" -Color Red
    exit 1
}

Write-Message ''
Write-Header "Step 3: Generate Client Secret"

Write-Message 'Generating client secret...' -Color Yellow

try {
    # Create a new credential with 1 year expiration
    $credential = az ad app credential reset `
        --id $appId `
        --years 1 `
        --output json | ConvertFrom-Json

    $clientSecret = $credential.password
    Write-Message '[OK] Client secret generated (expires in 1 year)' -Color Green
}
catch {
    Write-Message "[ERROR] Failed to generate client secret: $_" -Color Red
    exit 1
}

Write-Message ''
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

Write-Message '[OK] Saved credentials to .keys directory' -Color Green
Write-Message "  Client ID: $clientIdFile"
Write-Message "  Client Secret: $clientSecretFile"
Write-Message "  Tenant ID: $tenantIdFile"

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

Write-Message ''
Write-Header "Setup Complete!"

Write-Message 'M2M authentication configured successfully!' -Color Green
Write-Message ''
Write-Message 'Credentials saved to:' -Color Yellow
Write-Message "  $OutputDirectory"
Write-Message ''
Write-Message "See $summaryFile for usage instructions" -Color Blue
Write-Message ''
Write-Message "Next: Use 'pwsh scripts/local/get-m2m-token.ps1' to generate access tokens" -Color Cyan
Write-Message ''
Write-Message 'Important: Client secret expires in 1 year!' -Color Red
Write-Message ''
