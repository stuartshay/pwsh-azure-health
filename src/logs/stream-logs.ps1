#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stream real-time logs from Azure Function App.

.DESCRIPTION
    Streams live logs from the Function App using Azure CLI log tail.
    Shows all function executions and system messages in real-time.

.PARAMETER Environment
    Environment: dev or prod (default: dev)

.PARAMETER Filter
    Filter logs by keyword

.EXAMPLE
    ./stream-logs.ps1

.EXAMPLE
    ./stream-logs.ps1 -Environment prod

.EXAMPLE
    ./stream-logs.ps1 -Filter "GetServiceHealthTimer"
#>

param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [string]$Filter
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
Write-ColorOutput "Azure Function Log Stream" $script:Blue
Write-ColorOutput "========================================" $script:Blue
Write-Host ""

$resourceGroup = "rg-azure-health-$Environment"

Write-ColorOutput "Configuration:" $script:Cyan
Write-Host "  Environment:    $Environment"
Write-Host "  Resource Group: $resourceGroup"
if ($Filter) {
    Write-Host "  Filter:         $Filter"
}
Write-Host ""

# Get Function App name
Write-ColorOutput "Getting Function App..." $script:Yellow
$functionApp = az functionapp list --resource-group $resourceGroup --query '[0].name' -o tsv

if (-not $functionApp) {
    Write-ColorOutput "✗ Function App not found in $resourceGroup" $script:Red
    exit 1
}

Write-ColorOutput "✓ Found: $functionApp" $script:Green
Write-Host ""
Write-ColorOutput "Streaming logs... (Press Ctrl+C to stop)" $script:Yellow
Write-Host ""
Write-ColorOutput "========================================" $script:Blue
Write-Host ""

if ($Filter) {
    az webapp log tail --resource-group $resourceGroup --name $functionApp --filter $Filter
} else {
    az webapp log tail --resource-group $resourceGroup --name $functionApp
}
