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
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information to emit status updates without relying on Write-Host.
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
$keysDir = Join-Path $repoRoot ".keys"

# Set default key file if not provided
if (-not $KeyFile) {
    $KeyFile = Join-Path $keysDir "default.key"
}

Write-Header "Azure Function API Test"

Write-Message 'Configuration:' -Color Yellow
Write-Message "  Environment: $Environment"
Write-Message "  Endpoint:    $Endpoint"
Write-Message "  Method:      $Method"
Write-Message "  Auth Method: $(if ($UseAzureAD) { 'Azure AD Token' } else { 'Function Key' })"
if (-not $UseAzureAD) {
    Write-Message "  Key File:    $KeyFile"
}
Write-Message ''

# Get Function App name from Azure
Write-Message 'Discovering Function App...' -Color Yellow
$resourceGroup = "rg-azure-health-$Environment"

try {
    $functionApps = az functionapp list --resource-group $resourceGroup --output json | ConvertFrom-Json
    if (-not $functionApps -or $functionApps.Count -eq 0) {
        Write-Message "[ERROR] No Function Apps found in resource group: $resourceGroup" -Color Red
        exit 1
    }
    $functionAppName = $functionApps[0].name
    $functionUrl = "https://$functionAppName.azurewebsites.net"
    Write-Message "[OK] Found Function App: $functionAppName" -Color Green
}
catch {
    Write-Message "[ERROR] Failed to discover Function App: $_" -Color Red
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
        Write-Message 'Generating Azure AD access token...' -Color Yellow
        $tokenScript = Join-Path $repoRoot "scripts/local/get-m2m-token.ps1"

        if (-not (Test-Path $tokenScript)) {
            Write-Message "[ERROR] Token generation script not found: $tokenScript" -Color Red
            exit 1
        }

        try {
            $accessToken = & $tokenScript -OutputOnly
            if ([string]::IsNullOrWhiteSpace($accessToken)) {
                Write-Message '[ERROR] Failed to generate access token' -Color Red
                exit 1
            }
            Write-Message '[OK] Generated Azure AD access token' -Color Green
        }
        catch {
            Write-Message "[ERROR] Failed to generate access token: $_" -Color Red
            Write-Message ''
            Write-Message 'Run this command to setup M2M authentication:' -Color Yellow
            Write-Message '  pwsh scripts/setup/setup-m2m-auth.ps1'
            Write-Message ''
            exit 1
        }
    }
    else {
        # Use function key
        if (-not (Test-Path $KeyFile)) {
            Write-Message "[ERROR] Key file not found: $KeyFile" -Color Red
            Write-Message ''
            Write-Message 'Run this command to download keys:' -Color Yellow
            Write-Message '  pwsh scripts/local/get-function-keys.ps1'
            Write-Message ''
            exit 1
        }

        $functionKey = Get-Content $KeyFile -Raw
        if ([string]::IsNullOrWhiteSpace($functionKey)) {
            Write-Message "[ERROR] Key file is empty: $KeyFile" -Color Red
            exit 1
        }
        Write-Message '[OK] Loaded function key' -Color Green
    }
}
else {
    Write-Message '[INFO] Health endpoint - no authentication required' -Color Cyan
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
    Write-Message ''
    Write-Message 'Request Details:' -Color Cyan
    Write-Message "  URL:    $apiUrl"
    Write-Message "  Method: $Method"
    Write-Message '  Headers:'
    foreach ($key in $headers.Keys) {
        $value = switch ($key) {
            'x-functions-key' { '[REDACTED]' }
            'Authorization' { '[REDACTED]' }
            default { $headers[$key] }
        }
        Write-Message "    $key`: $value"
    }
    if ($requestParams.Body) {
        Write-Message '  Body:'
        Write-Message "    $($requestParams.Body)"
    }
}

# Make the API call
Write-Message ''
Write-Message 'Calling API...' -Color Yellow

try {
    $response = Invoke-RestMethod @requestParams -ErrorAction Stop

    Write-Message '[OK] Request successful!' -Color Green
    Write-Message ''
    Write-Message 'Response:' -Color Cyan
    Write-Message ($response | ConvertTo-Json -Depth 10)
    Write-Message ''

    if ($ShowDetails) {
        Write-Message "Response Type: $($response.GetType().Name)" -Color Cyan
        if ($response -is [PSCustomObject] -and $response.status) {
            Write-Message "Status: $($response.status)" -Color Green
        }
    }
}
catch {
    Write-Message '[ERROR] Request failed!' -Color Red
    Write-Message ''

    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDesc = $_.Exception.Response.StatusDescription
        Write-Message "HTTP Status: $statusCode $statusDesc" -Color Red

        if ($_.ErrorDetails.Message) {
            Write-Message ''
            Write-Message 'Error Details:' -Color Yellow
            Write-Message $_.ErrorDetails.Message
        }
    }
    else {
        Write-Message $_.Exception.Message -Color Red
    }

    Write-Message ''
    exit 1
}

Write-Header "Test Complete"
