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
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information so scripts can emit status lines without relying on Write-Host.
.PARAMETER Message
    Text to write to the information stream.
.PARAMETER Color
    Optional color to apply when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('Default', 'Blue', 'Cyan', 'Gray', 'Green', 'Red', 'Yellow')]
        [string]$Color = 'Default'
    )

    if ($OutputOnly) {
        return
    }

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
    if ($OutputOnly) {
        return
    }

    Write-Message ''
    Write-Message '========================================' -Color Blue
    Write-Message $Message -Color Blue
    Write-Message '========================================' -Color Blue
    Write-Message ''
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

Write-Header 'Azure AD M2M Token Generator'

# Load credentials
Write-Message 'Loading credentials...' -Color Yellow

if (-not (Test-Path $ClientIdFile)) {
    Write-Message "[ERROR] Client ID file not found: $ClientIdFile" -Color Red
    Write-Message 'Run: pwsh scripts/setup/setup-m2m-auth.ps1' -Color Yellow
    exit 1
}

if (-not (Test-Path $ClientSecretFile)) {
    Write-Message "[ERROR] Client secret file not found: $ClientSecretFile" -Color Red
    Write-Message 'Run: pwsh scripts/setup/setup-m2m-auth.ps1' -Color Yellow
    exit 1
}

if (-not (Test-Path $TenantIdFile)) {
    Write-Message "[ERROR] Tenant ID file not found: $TenantIdFile" -Color Red
    Write-Message 'Run: pwsh scripts/setup/setup-m2m-auth.ps1' -Color Yellow
    exit 1
}

$clientId = Get-Content $ClientIdFile -Raw
$clientSecret = Get-Content $ClientSecretFile -Raw
$tenantId = Get-Content $TenantIdFile -Raw

Write-Message '[OK] Loaded credentials' -Color Green

# Auto-discover Function App if resource not specified
if (-not $Resource) {
    Write-Message 'Discovering Function App...' -Color Yellow
    $resourceGroup = "rg-azure-health-$Environment"

    try {
        $functionApps = az functionapp list --resource-group $resourceGroup --output json | ConvertFrom-Json
        if (-not $functionApps -or $functionApps.Count -eq 0) {
            Write-Message "[ERROR] No Function Apps found in resource group: $resourceGroup" -Color Red
            exit 1
        }
        $functionAppName = $functionApps[0].name
        $Resource = "https://$functionAppName.azurewebsites.net"
        Write-Message "[OK] Found Function App: $functionAppName" -Color Green
    }
    catch {
        Write-Message "[ERROR] Failed to discover Function App: $_" -Color Red
        exit 1
    }
}

# Request token
Write-Message ''
Write-Message 'Requesting access token...' -Color Yellow
Write-Message "  Resource: $Resource"

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

    if ($OutputOnly) {
        Write-Output $token
        return
    }

    Write-Message '[OK] Token generated successfully!' -Color Green

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

    Write-Message ''
    Write-Message 'Token Details:' -Color Cyan
    Write-Message "  Issuer: $($claims.iss)"
    Write-Message "  Audience: $($claims.aud)"
    Write-Message "  App ID: $($claims.appid)"
    Write-Message "  Issued: $(([DateTimeOffset]::FromUnixTimeSeconds($claims.iat)).LocalDateTime)"
    Write-Message "  Expires: $(([DateTimeOffset]::FromUnixTimeSeconds($claims.exp)).LocalDateTime)"

    $expiresIn = ([DateTimeOffset]::FromUnixTimeSeconds($claims.exp) - [DateTimeOffset]::Now).TotalMinutes
    Write-Message "  Valid for: $([Math]::Round($expiresIn, 0)) minutes"

    Write-Message ''
    Write-Message 'Access Token:' -Color Yellow
    if ($ShowToken) {
        Write-Message $token
    }
    else {
        $tokenPreview = $token.Substring(0, 20) + '...' + $token.Substring($token.Length - 20)
        Write-Message $tokenPreview
        Write-Message ''
        Write-Message 'Use -ShowToken to display full token' -Color Cyan
    }

    Write-Message ''
    Write-Message 'Usage Example:' -Color Yellow
    Write-Message @"
  `$token = pwsh scripts/local/get-m2m-token.ps1 -OutputOnly
  `$headers = @{ "Authorization" = "Bearer `$token" }
  Invoke-RestMethod -Uri "$Resource/api/GetServiceHealth" -Headers `$headers
"@
    Write-Message ''
}
catch {
    Write-Message "[ERROR] Failed to get access token: $_" -Color Red
    if ($_.ErrorDetails.Message) {
        Write-Message ''
        Write-Message 'Error Details:' -Color Yellow
        Write-Message $_.ErrorDetails.Message
    }
    exit 1
}
