#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test logging functionality by triggering the timer function.

.DESCRIPTION
    Manually triggers the GetServiceHealthTimer function to test logging,
    then displays the resulting logs from Application Insights.

.PARAMETER Environment
    Environment: dev or prod (default: dev)

.PARAMETER WaitSeconds
    Seconds to wait for logs to appear in App Insights (default: 15)

.EXAMPLE
    ./test-logging.ps1

.EXAMPLE
    ./test-logging.ps1 -Environment prod

.EXAMPLE
    ./test-logging.ps1 -WaitSeconds 30
#>

param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [int]$WaitSeconds = 15
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

Write-ColorOutput "========================================" $script:Blue
Write-ColorOutput "Test Timer Function Logging" $script:Blue
Write-ColorOutput "========================================" $script:Blue
Write-Host ""

$resourceGroup = "rg-azure-health-$Environment"

Write-ColorOutput "Configuration:" $script:Cyan
Write-Host "  Environment:    $Environment"
Write-Host "  Resource Group: $resourceGroup"
Write-Host ""

# Get Function App details
Write-ColorOutput "Getting Function App details..." $script:Yellow
$functionApp = az functionapp list --resource-group $resourceGroup --query '[0].name' -o tsv

if (-not $functionApp) {
    Write-ColorOutput "✗ Function App not found in $resourceGroup" $script:Red
    exit 1
}

Write-ColorOutput "✓ Found: $functionApp" $script:Green

# Get master key
$masterKey = az functionapp keys list --resource-group $resourceGroup --name $functionApp --query 'masterKey' -o tsv

if (-not $masterKey) {
    Write-ColorOutput "✗ Failed to get master key" $script:Red
    exit 1
}

Write-ColorOutput "✓ Retrieved master key" $script:Green
Write-Host ""

# Trigger the timer function
$url = "https://$functionApp.azurewebsites.net/admin/functions/GetServiceHealthTimer"
$headers = @{
    'x-functions-key' = $masterKey
    'Content-Type'    = 'application/json'
}

try {
    Write-ColorOutput "Triggering GetServiceHealthTimer function..." $script:Yellow
    Write-Host "  URL: $url" -ForegroundColor Gray
    Write-Host ""

    $null = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body '{}' -ErrorAction Stop

    Write-ColorOutput "✓ Timer function triggered successfully!" $script:Green
    Write-Host ""

    Write-ColorOutput "Waiting $WaitSeconds seconds for logs to appear in Application Insights..." $script:Yellow

    for ($i = $WaitSeconds; $i -gt 0; $i--) {
        Write-Host "`r  Remaining: $i seconds... " -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 1
    }
    Write-Host ""
    Write-Host ""

    Write-ColorOutput "Querying recent logs..." $script:Cyan
    Write-Host ""

    # Query logs from the last hour
    $scriptDir = Split-Path -Parent $PSCommandPath
    & "$scriptDir/query-timer-logs.ps1" -Hours 1 -Environment $Environment
}
catch {
    Write-Host ""
    Write-ColorOutput "✗ Failed to trigger timer: $($_.Exception.Message)" $script:Red

    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "  HTTP Status: $statusCode" -ForegroundColor Red
    }

    exit 1
}
