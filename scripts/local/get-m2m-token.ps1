#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates Azure AD access token for machine-to-machine authentication.

.DESCRIPTION
    Uses service principal credentials to obtain an OAuth 2.0 access token
    for calling Azure Function App APIs. Supports both interactive display
    and piping to other commands.

.PARAMETER Resource
    Target resource URL. Defaults to auto-discovered Function App URL.

.PARAMETER Environment
    Environment (dev, prod). Defaults to dev.

.PARAMETER ClientIdFile
    Path to file containing client ID. Defaults to .keys/m2m-client-id.txt.

.PARAMETER ClientSecretFile
    Path to file containing client secret. Defaults to .keys/m2m-client-secret.key.

.PARAMETER TenantIdFile
    Path to file containing tenant ID. Defaults to .keys/m2m-tenant-id.txt.

.PARAMETER ShowToken
    Display the full token (default shows only first/last characters).

.PARAMETER OutputOnly
    Output only the token without any formatting (useful for piping).

.EXAMPLE
    ./get-m2m-token.ps1

.EXAMPLE
    ./get-m2m-token.ps1 -ShowToken

.EXAMPLE
    ./get-m2m-token.ps1 -OutputOnly

.EXAMPLE
    # Use in a script
    $token = pwsh scripts/local/get-m2m-token.ps1 -OutputOnly
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Resource,

    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$ClientIdFile,

    [Parameter()]
    [string]$ClientSecretFile,

    [Parameter()]
    [string]$TenantIdFile,

    [Parameter()]
    [switch]$ShowToken,

    [Parameter()]
    [switch]$OutputOnly
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
    if (-not $OutputOnly) {
        Write-Host "${Color}${Message}${script:Reset}"
    }
}

function Write-Header {
    param([string]$Message)
    if (-not $OutputOnly) {
        Write-Host ""
        Write-ColorOutput "========================================" $script:Blue
        Write-ColorOutput $Message $script:Blue
        Write-ColorOutput "========================================" $script:Blue
        Write-Host ""
    }
}

# Determine repository root
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$keysDir = Join-Path $repoRoot ".keys"

# Set default credential files
if (-not $ClientIdFile) {
    $ClientIdFile = Join-Path $keysDir "m2m-client-id.txt"
}
if (-not $ClientSecretFile) {
    $ClientSecretFile = Join-Path $keysDir "m2m-client-secret.key"
}
if (-not $TenantIdFile) {
    $TenantIdFile = Join-Path $keysDir "m2m-tenant-id.txt"
}

if (-not $OutputOnly) {
    Write-Header "Azure AD M2M Token Generator"
}

# Load credentials
Write-ColorOutput "Loading credentials..." $script:Yellow

if (-not (Test-Path $ClientIdFile)) {
    Write-ColorOutput "✗ Client ID file not found: $ClientIdFile" $script:Red
    Write-ColorOutput "Run: pwsh scripts/setup/setup-m2m-auth.ps1" $script:Yellow
    exit 1
}

if (-not (Test-Path $ClientSecretFile)) {
    Write-ColorOutput "✗ Client secret file not found: $ClientSecretFile" $script:Red
    Write-ColorOutput "Run: pwsh scripts/setup/setup-m2m-auth.ps1" $script:Yellow
    exit 1
}

if (-not (Test-Path $TenantIdFile)) {
    Write-ColorOutput "✗ Tenant ID file not found: $TenantIdFile" $script:Red
    Write-ColorOutput "Run: pwsh scripts/setup/setup-m2m-auth.ps1" $script:Yellow
    exit 1
}

$clientId = Get-Content $ClientIdFile -Raw
$clientSecret = Get-Content $ClientSecretFile -Raw
$tenantId = Get-Content $TenantIdFile -Raw

Write-ColorOutput "✓ Loaded credentials" $script:Green

# Auto-discover Function App if resource not specified
if (-not $Resource) {
    Write-ColorOutput "Discovering Function App..." $script:Yellow
    $resourceGroup = "rg-azure-health-$Environment"

    try {
        $functionApps = az functionapp list --resource-group $resourceGroup --output json | ConvertFrom-Json
        if (-not $functionApps -or $functionApps.Count -eq 0) {
            Write-ColorOutput "✗ No Function Apps found in resource group: $resourceGroup" $script:Red
            exit 1
        }
        $functionAppName = $functionApps[0].name
        $Resource = "https://$functionAppName.azurewebsites.net"
        Write-ColorOutput "✓ Found Function App: $functionAppName" $script:Green
    }
    catch {
        Write-ColorOutput "✗ Failed to discover Function App: $_" $script:Red
        exit 1
    }
}

# Request token
if (-not $OutputOnly) {
    Write-Host ""
    Write-ColorOutput "Requesting access token..." $script:Yellow
    Write-Host "  Resource: $Resource"
}

try {
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    $body = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "$Resource/.default"
        grant_type    = "client_credentials"
    }

    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ErrorAction Stop
    $token = $response.access_token

    if (-not $OutputOnly) {
        Write-ColorOutput "✓ Token generated successfully!" $script:Green

        # Decode token to show claims (handle base64url encoding)
        $tokenParts = $token.Split('.')
        $base64 = $tokenParts[1].Replace('-', '+').Replace('_', '/')
        # Add padding if needed
        switch ($base64.Length % 4) {
            2 { $base64 += '==' }
            3 { $base64 += '=' }
        }
        $payload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($base64))
        $claims = $payload | ConvertFrom-Json

        Write-Host ""
        Write-ColorOutput "Token Details:" $script:Cyan
        Write-Host "  Issuer: $($claims.iss)"
        Write-Host "  Audience: $($claims.aud)"
        Write-Host "  App ID: $($claims.appid)"
        Write-Host "  Issued: $(([DateTimeOffset]::FromUnixTimeSeconds($claims.iat)).LocalDateTime)"
        Write-Host "  Expires: $(([DateTimeOffset]::FromUnixTimeSeconds($claims.exp)).LocalDateTime)"

        $expiresIn = ([DateTimeOffset]::FromUnixTimeSeconds($claims.exp) - [DateTimeOffset]::Now).TotalMinutes
        Write-Host "  Valid for: $([Math]::Round($expiresIn, 0)) minutes"

        Write-Host ""
        if ($ShowToken) {
            Write-ColorOutput "Access Token:" $script:Yellow
            Write-Host $token
        }
        else {
            Write-ColorOutput "Access Token:" $script:Yellow
            $tokenPreview = $token.Substring(0, 20) + "..." + $token.Substring($token.Length - 20)
            Write-Host $tokenPreview
            Write-Host ""
            Write-ColorOutput "Use -ShowToken to display full token" $script:Cyan
        }

        Write-Host ""
        Write-ColorOutput "Usage Example:" $script:Yellow
        Write-Host @"
  `$token = pwsh scripts/local/get-m2m-token.ps1 -OutputOnly
  `$headers = @{ "Authorization" = "Bearer `$token" }
  Invoke-RestMethod -Uri "$Resource/api/GetServiceHealth" -Headers `$headers
"@
        Write-Host ""
    }
    else {
        # Output only mode - just print the token
        Write-Output $token
    }
}
catch {
    Write-ColorOutput "✗ Failed to get access token: $_" $script:Red
    if ($_.ErrorDetails.Message) {
        Write-Host ""
        Write-ColorOutput "Error Details:" $script:Yellow
        Write-Host $_.ErrorDetails.Message
    }
    exit 1
}
