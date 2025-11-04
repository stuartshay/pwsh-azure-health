#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Query GetServiceHealthTimer execution logs from Application Insights.

.DESCRIPTION
    Queries Application Insights for GetServiceHealthTimer function logs with
    customizable time ranges and filtering options.

.PARAMETER Hours
    Number of hours to look back (default: 24)

.PARAMETER Environment
    Environment: dev or prod (default: dev)

.PARAMETER ShowErrors
    Show only errors and critical messages

.PARAMETER ShowSummary
    Show execution summary statistics

.EXAMPLE
    ./query-timer-logs.ps1

.EXAMPLE
    ./query-timer-logs.ps1 -Hours 48

.EXAMPLE
    ./query-timer-logs.ps1 -ShowErrors

.EXAMPLE
    ./query-timer-logs.ps1 -ShowSummary
#>

param(
    [Parameter()]
    [int]$Hours = 24,

    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [switch]$ShowErrors,

    [Parameter()]
    [switch]$ShowSummary
)

$ErrorActionPreference = 'Stop'

# Colors for output
$script:Green = "`e[32m"
$script:Yellow = "`e[33m"
$script:Red = "`e[31m"
$script:Blue = "`e[34m"
$script:Cyan = "`e[36m"
$script:Gray = "`e[90m"
$script:Reset = "`e[0m"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $script:Reset
    )
    Write-Host "${Color}${Message}${script:Reset}"
}

Write-ColorOutput "========================================" $script:Blue
Write-ColorOutput "Azure Function Timer Logs Query" $script:Blue
Write-ColorOutput "========================================" $script:Blue
Write-Host ""

$resourceGroup = "rg-azure-health-$Environment"

Write-ColorOutput "Configuration:" $script:Cyan
Write-Host "  Environment:    $Environment"
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Time Range:     Last $Hours hours"
Write-Host ""

# Get Application Insights resource
Write-ColorOutput "Getting Application Insights..." $script:Yellow
$appInsightsJson = az monitor app-insights component show --resource-group $resourceGroup --query '[0]' 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "✗ Application Insights not found in $resourceGroup" $script:Red
    exit 1
}

$appInsights = $appInsightsJson | ConvertFrom-Json

Write-ColorOutput "✓ Found: $($appInsights.name)" $script:Green
Write-Host ""

if ($ShowSummary) {
    $summaryQuery = @"
requests
| where timestamp > ago($($Hours)h)
| where name == "GetServiceHealthTimer"
| summarize
    Executions = count(),
    Successes = countif(success == true),
    Failures = countif(success == false),
    AvgDurationMs = avg(duration),
    MaxDurationMs = max(duration)
"@

    Write-ColorOutput "Querying execution summary..." $script:Yellow
    $summaryResults = az monitor app-insights query `
        --app $appInsights.appId `
        --analytics-query $summaryQuery `
        --output json | ConvertFrom-Json

    if ($summaryResults.tables -and $summaryResults.tables[0].rows) {
        $row = $summaryResults.tables[0].rows[0]
        Write-ColorOutput "Execution Summary:" $script:Cyan
        Write-Host "  Total Executions: $($row[0])"
        Write-Host "  Successes:        $($row[1])" -ForegroundColor Green
        Write-Host "  Failures:         $($row[2])" -ForegroundColor $(if ($row[2] -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Avg Duration:     $([Math]::Round($row[3], 2)) ms"
        Write-Host "  Max Duration:     $([Math]::Round($row[4], 2)) ms"
        Write-Host ""
    }
}

# Build the main query
if ($ShowErrors) {
    $query = @"
traces
| where timestamp > ago($($Hours)h)
| where cloud_RoleName contains "azurehealth-func"
| where severityLevel >= 3
| where message contains "GetServiceHealthTimer" or operation_Name == "GetServiceHealthTimer"
| order by timestamp desc
| project timestamp, severityLevel, message
"@
    Write-ColorOutput "Querying error logs..." $script:Yellow
} else {
    $query = @"
traces
| where timestamp > ago($($Hours)h)
| where cloud_RoleName contains "azurehealth-func"
| where operation_Name == "GetServiceHealthTimer" or message contains "GetServiceHealthTimer"
| order by timestamp desc
| project timestamp, severityLevel, message
"@
    Write-ColorOutput "Querying all logs..." $script:Yellow
}

$results = az monitor app-insights query `
    --app $appInsights.appId `
    --analytics-query $query `
    --output json | ConvertFrom-Json

if ($results.tables -and $results.tables[0].rows) {
    Write-ColorOutput "✓ Found $($results.tables[0].rows.Count) log entries" $script:Green
    Write-Host ""
    Write-ColorOutput "Logs:" $script:Cyan
    Write-Host ""

    foreach ($row in $results.tables[0].rows) {
        $timestamp = [DateTime]::Parse($row[0]).ToLocalTime().ToString("yyyy-MM-dd HH:mm:ss")
        $severity = $row[1]
        $message = $row[2]

        $severityName = switch ($severity) {
            0 { "VERBOSE" }
            1 { "INFO   " }
            2 { "WARNING" }
            3 { "ERROR  " }
            4 { "CRITICAL" }
            default { "UNKNOWN" }
        }

        $color = switch ($severity) {
            0 { $script:Gray }
            1 { $script:Reset }
            2 { $script:Yellow }
            3 { $script:Red }
            4 { $script:Red }
            default { $script:Reset }
        }

        Write-Host "[$timestamp] " -ForegroundColor Cyan -NoNewline
        Write-Host "[$severityName] " -ForegroundColor $color -NoNewline
        Write-Host "$message"
    }
} else {
    Write-ColorOutput "No logs found in the specified time range." $script:Yellow
}

Write-Host ""
Write-ColorOutput "========================================" $script:Blue
Write-ColorOutput "Query Complete" $script:Blue
Write-ColorOutput "========================================" $script:Blue
