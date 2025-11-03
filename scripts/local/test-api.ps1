#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test Azure Function API using saved function keys or Azure AD tokens.

.DESCRIPTION
    Calls Azure Function API endpoints using either function keys stored in .keys directory
    or Azure AD M2M tokens. Automatically loads the default key and provides convenient
    parameters for testing.

.PARAMETER Endpoint
    API endpoint to call (e.g., 'GetServiceHealth', 'health'). Defaults to GetServiceHealth.

.PARAMETER Environment
    Environment to test (dev, prod). Defaults to dev.

.PARAMETER KeyFile
    Path to key file. Defaults to .keys/default.key.

.PARAMETER UseAzureAD
    Use Azure AD M2M token instead of function key.

.PARAMETER Method
    HTTP method (GET, POST). Defaults to GET.

.PARAMETER Body
    Request body for POST requests (as JSON string or hashtable).

.PARAMETER ShowDetails
    Show detailed request/response information.

.EXAMPLE
    # Test health endpoint (no key required)
    ./test-api.ps1 -Endpoint health

.EXAMPLE
    # Test GetServiceHealth endpoint with function key
    ./test-api.ps1 -Endpoint GetServiceHealth

.EXAMPLE
    # Test GetServiceHealth endpoint with Azure AD token
    ./test-api.ps1 -Endpoint GetServiceHealth -UseAzureAD

.EXAMPLE
    # Test with custom key file
    ./test-api.ps1 -Endpoint GetServiceHealth -KeyFile .keys/custom.key

.EXAMPLE
    # Test with POST and body
    ./test-api.ps1 -Endpoint GetServiceHealth -Method POST -Body @{SubscriptionId="xxx"}

.EXAMPLE
    # Show detailed request/response info
    ./test-api.ps1 -Endpoint GetServiceHealth -ShowDetails
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Endpoint = 'GetServiceHealth',

    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$KeyFile,

    [Parameter()]
    [switch]$UseAzureAD,

    [Parameter()]
    [ValidateSet('GET', 'POST', 'HEAD')]
    [string]$Method = 'GET',

    [Parameter()]
    [object]$Body,

    [Parameter()]
    [switch]$ShowDetails
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
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$keysDir = Join-Path $repoRoot ".keys"

# Set default key file if not provided
if (-not $KeyFile) {
    $KeyFile = Join-Path $keysDir "default.key"
}

Write-Header "Azure Function API Test"

Write-ColorOutput "Configuration:" $script:Yellow
Write-Host "  Environment: $Environment"
Write-Host "  Endpoint:    $Endpoint"
Write-Host "  Method:      $Method"
Write-Host "  Auth Method: $(if ($UseAzureAD) { 'Azure AD Token' } else { 'Function Key' })"
if (-not $UseAzureAD) {
    Write-Host "  Key File:    $KeyFile"
}
Write-Host ""

# Get Function App name from Azure
Write-ColorOutput "Discovering Function App..." $script:Yellow
$resourceGroup = "rg-azure-health-$Environment"

try {
    $functionApps = az functionapp list --resource-group $resourceGroup --output json | ConvertFrom-Json
    if (-not $functionApps -or $functionApps.Count -eq 0) {
        Write-ColorOutput "✗ No Function Apps found in resource group: $resourceGroup" $script:Red
        exit 1
    }
    $functionAppName = $functionApps[0].name
    $functionUrl = "https://$functionAppName.azurewebsites.net"
    Write-ColorOutput "✓ Found Function App: $functionAppName" $script:Green
}
catch {
    Write-ColorOutput "✗ Failed to discover Function App: $_" $script:Red
    exit 1
}

# Build API URL
$apiUrl = "$functionUrl/api/$Endpoint"

# Check if endpoint requires authentication
$requiresAuth = $Endpoint -ne 'health'

# Load authentication credentials if required
$functionKey = $null
$accessToken = $null

if ($requiresAuth) {
    if ($UseAzureAD) {
        # Use Azure AD M2M token
        Write-ColorOutput "Generating Azure AD access token..." $script:Yellow
        $tokenScript = Join-Path $repoRoot "scripts/local/get-m2m-token.ps1"

        if (-not (Test-Path $tokenScript)) {
            Write-ColorOutput "✗ Token generation script not found: $tokenScript" $script:Red
            exit 1
        }

        try {
            $accessToken = & $tokenScript -OutputOnly
            if ([string]::IsNullOrWhiteSpace($accessToken)) {
                Write-ColorOutput "✗ Failed to generate access token" $script:Red
                exit 1
            }
            Write-ColorOutput "✓ Generated Azure AD access token" $script:Green
        }
        catch {
            Write-ColorOutput "✗ Failed to generate access token: $_" $script:Red
            Write-Host ""
            Write-ColorOutput "Run this command to setup M2M authentication:" $script:Yellow
            Write-Host "  pwsh scripts/setup/setup-m2m-auth.ps1"
            Write-Host ""
            exit 1
        }
    }
    else {
        # Use function key
        if (-not (Test-Path $KeyFile)) {
            Write-ColorOutput "✗ Key file not found: $KeyFile" $script:Red
            Write-Host ""
            Write-ColorOutput "Run this command to download keys:" $script:Yellow
            Write-Host "  pwsh scripts/local/get-function-keys.ps1"
            Write-Host ""
            exit 1
        }

        $functionKey = Get-Content $KeyFile -Raw
        if ([string]::IsNullOrWhiteSpace($functionKey)) {
            Write-ColorOutput "✗ Key file is empty: $KeyFile" $script:Red
            exit 1
        }
        Write-ColorOutput "✓ Loaded function key" $script:Green
    }
}
else {
    Write-ColorOutput "ℹ  Health endpoint - no authentication required" $script:Cyan
}

# Prepare headers
$headers = @{
    'Accept' = 'application/json'
}

if ($requiresAuth) {
    if ($UseAzureAD -and $accessToken) {
        $headers['Authorization'] = "Bearer $accessToken"
    }
    elseif ($functionKey) {
        $headers['x-functions-key'] = $functionKey
    }
}

# Prepare request parameters
$requestParams = @{
    Uri     = $apiUrl
    Method  = $Method
    Headers = $headers
}

# Add body for POST requests
if ($Method -eq 'POST' -and $Body) {
    if ($Body -is [hashtable] -or $Body -is [PSCustomObject]) {
        $requestParams['Body'] = ($Body | ConvertTo-Json -Depth 10)
        $headers['Content-Type'] = 'application/json'
    }
    else {
        $requestParams['Body'] = $Body
        $headers['Content-Type'] = 'application/json'
    }
}

# Show request details if requested
if ($ShowDetails) {
    Write-Host ""
    Write-ColorOutput "Request Details:" $script:Cyan
    Write-Host "  URL:    $apiUrl"
    Write-Host "  Method: $Method"
    Write-Host "  Headers:"
    foreach ($key in $headers.Keys) {
        $value = switch ($key) {
            'x-functions-key' { "[REDACTED]" }
            'Authorization' { "[REDACTED]" }
            default { $headers[$key] }
        }
        Write-Host "    $key`: $value"
    }
    if ($requestParams.Body) {
        Write-Host "  Body:"
        Write-Host "    $($requestParams.Body)"
    }
}

# Make the API call
Write-Host ""
Write-ColorOutput "Calling API..." $script:Yellow

try {
    $response = Invoke-RestMethod @requestParams -ErrorAction Stop

    Write-ColorOutput "✓ Request successful!" $script:Green
    Write-Host ""
    Write-ColorOutput "Response:" $script:Cyan
    Write-Host ($response | ConvertTo-Json -Depth 10)
    Write-Host ""

    if ($ShowDetails) {
        Write-ColorOutput "Response Type: $($response.GetType().Name)" $script:Cyan
        if ($response -is [PSCustomObject] -and $response.status) {
            Write-ColorOutput "Status: $($response.status)" $script:Green
        }
    }
}
catch {
    Write-ColorOutput "✗ Request failed!" $script:Red
    Write-Host ""

    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDesc = $_.Exception.Response.StatusDescription
        Write-ColorOutput "HTTP Status: $statusCode $statusDesc" $script:Red

        if ($_.ErrorDetails.Message) {
            Write-Host ""
            Write-ColorOutput "Error Details:" $script:Yellow
            Write-Host $_.ErrorDetails.Message
        }
    }
    else {
        Write-Host $_.Exception.Message
    }

    Write-Host ""
    exit 1
}

Write-Header "Test Complete"
