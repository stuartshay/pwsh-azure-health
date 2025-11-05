#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test health dashboard analytics by reading cached Service Health data.

.DESCRIPTION
    Reads the cached Service Health events from blob storage and calculates
    comprehensive dashboard statistics including event counts, top affected
    services/regions, historical trends, and cache metrics.

.PARAMETER Environment
    Environment: dev or prod (default: dev)

.PARAMETER Detailed
    Show detailed event breakdowns

.PARAMETER Json
    Output results as JSON instead of formatted console output

.PARAMETER TopN
    Number of top items to show for services/regions (default: 5)

.EXAMPLE
    ./test-health-dashboard.ps1

.EXAMPLE
    ./test-health-dashboard.ps1 -Environment prod -Detailed

.EXAMPLE
    ./test-health-dashboard.ps1 -Json
#>

param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [switch]$Detailed,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [int]$TopN = 5
)

$ErrorActionPreference = 'Stop'

# Colors for output
$script:Green = "`e[32m"
$script:Yellow = "`e[33m"
$script:Red = "`e[31m"
$script:Blue = "`e[34m"
$script:Cyan = "`e[36m"
$script:Magenta = "`e[35m"
$script:Reset = "`e[0m"

<#
.SYNOPSIS
${1:Short description}

.DESCRIPTION
${2:Long description}

.PARAMETER Message
${3:Parameter description}

.PARAMETER Color
${4:Parameter description}

.EXAMPLE
${5:An example}

.NOTES
${6:General notes}
#>
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = $script:Reset
    )
    if (-not $Json) {
        Write-Host "${Color}${Message}${script:Reset}"
    }
}

<#
.SYNOPSIS
${1:Short description}

.DESCRIPTION
${2:Long description}

.PARAMETER CachedData
${3:Parameter description}

.PARAMETER TopCount
${4:Parameter description}

.EXAMPLE
${5:An example}

.NOTES
${6:General notes}
#>
function Get-ServiceHealthDashboard {
    param(
        [Parameter(Mandatory = $true)]
        $CachedData,

        [int]$TopCount = 5
    )

    $now = [DateTime]::UtcNow
    $events = $CachedData.events

    # Calculate cache metrics
    $lastQueryTime = $null
    if ($CachedData.cachedAt) {
        try {
            $lastQueryTime = [DateTime]::Parse($CachedData.cachedAt)
        }
        catch {
            Write-Warning "Invalid cachedAt date format: $($CachedData.cachedAt)"
            $lastQueryTime = $null
        }
    }

    $cacheAge = if ($lastQueryTime) {
        ($now - $lastQueryTime)
    }
    else {
        $null
    }

    # Calculate event statistics
    $totalEvents = $events.Count

    $eventsByType = $events | Group-Object -Property {
        $_.EventType
    } | ForEach-Object {
        @{
            type  = $_.Name
            count = $_.Count
        }
    }

    $eventsByStatus = $events | Group-Object -Property {
        $_.Status
    } | ForEach-Object {
        @{
            status = $_.Name
            count  = $_.Count
        }
    }

    $eventsByLevel = $events | Group-Object -Property {
        $_.Level
    } | ForEach-Object {
        @{
            level = $_.Name
            count = $_.Count
        }
    }

    # Extract and count affected services
    $serviceCount = @{}
    foreach ($evt in $events) {
        if ($evt.ImpactedServices) {
            foreach ($svc in $evt.ImpactedServices) {
                $serviceName = if ($svc.ImpactedService) { $svc.ImpactedService } elseif ($svc.ServiceName) { $svc.ServiceName } else { $svc }
                if ($serviceName) {
                    if ($serviceCount.ContainsKey($serviceName)) {
                        $serviceCount[$serviceName]++
                    }
                    else {
                        $serviceCount[$serviceName] = 1
                    }
                }
            }
        }
    }

    $topServices = $serviceCount.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -First $TopCount |
        ForEach-Object {
            @{
                service = $_.Key
                count   = $_.Value
            }
        }

    # Extract and count affected regions
    $regionCount = @{}
    foreach ($evt in $events) {
        if ($evt.ImpactedServices) {
            foreach ($svc in $evt.ImpactedServices) {
                if ($svc.ImpactedRegions) {
                    foreach ($region in $svc.ImpactedRegions) {
                        $regionName = if ($region.ImpactedRegion) { $region.ImpactedRegion } elseif ($region.RegionName) { $region.RegionName } else { $region }
                        if ($regionName) {
                            if ($regionCount.ContainsKey($regionName)) {
                                $regionCount[$regionName]++
                            }
                            else {
                                $regionCount[$regionName] = 1
                            }
                        }
                    }
                }
            }
        }
    }

    $topRegions = $regionCount.GetEnumerator() |
        Sort-Object -Property Value -Descending |
        Select-Object -First $TopCount |
        ForEach-Object {
            @{
                region = $_.Key
                count  = $_.Value
            }
        }

    # Parse all event times once for efficiency and safety
    $eventTimes = @()
    foreach ($evt in $events) {
        if ($evt.LastUpdateTime) {
            try {
                $eventTimes += [DateTime]::Parse($evt.LastUpdateTime)
            }
            catch {
                Write-Verbose "Skipping event with invalid date: $($evt.LastUpdateTime)"
            }
        }
    }

    # Calculate time-based trends using cached parsed times
    $last24Hours = ($eventTimes | Where-Object { ($now - $_).TotalHours -le 24 }).Count

    $last7Days = ($eventTimes | Where-Object { ($now - $_).TotalDays -le 7 }).Count

    $last30Days = ($eventTimes | Where-Object { ($now - $_).TotalDays -le 30 }).Count

    # Find oldest and newest events using cached parsed times
    $oldestEvent = if ($eventTimes.Count -gt 0) { ($eventTimes | Measure-Object -Minimum).Minimum } else { $null }
    $newestEvent = if ($eventTimes.Count -gt 0) { ($eventTimes | Measure-Object -Maximum).Maximum } else { $null }

    # Count active issues
    $activeIssues = ($events | Where-Object { $_.Status -eq 'Active' }).Count

    # Build dashboard object
    return [ordered]@{
        systemStatus = [ordered]@{
            apiVersion       = '1.0.0'
            cacheLastUpdated = if ($lastQueryTime) { $lastQueryTime.ToString('o') } else { $null }
            cacheAge         = if ($cacheAge) { "$([int]$cacheAge.TotalMinutes) minutes" } else { 'Unknown' }
            nextUpdate       = if ($lastQueryTime) { $lastQueryTime.AddMinutes(15).ToString('o') } else { $null }
            dataHealth       = if ($cacheAge -and $cacheAge.TotalMinutes -lt 20) { 'Healthy' } else { 'Stale' }
        }
        statistics   = [ordered]@{
            totalEventsInCache = $totalEvents
            activeIssues       = $activeIssues
            eventsByType       = $eventsByType
            eventsByStatus     = $eventsByStatus
            eventsByLevel      = $eventsByLevel
            dateRange          = [ordered]@{
                oldestEvent = if ($oldestEvent) { $oldestEvent.ToString('o') } else { $null }
                newestEvent = if ($newestEvent) { $newestEvent.ToString('o') } else { $null }
            }
        }
        topAffected  = [ordered]@{
            services = $topServices
            regions  = $topRegions
        }
        trends       = [ordered]@{
            last24Hours = $last24Hours
            last7Days   = $last7Days
            last30Days  = $last30Days
        }
    }
}

# Main execution
if (-not $Json) {
    Write-ColorOutput "========================================" $script:Blue
    Write-ColorOutput "Health Dashboard Analytics" $script:Blue
    Write-ColorOutput "========================================" $script:Blue
    Write-Host ""
}

$resourceGroup = "rg-azure-health-$Environment"

if (-not $Json) {
    Write-ColorOutput "Configuration:" $script:Cyan
    Write-Host "  Environment:    $Environment"
    Write-Host "  Resource Group: $resourceGroup"
    Write-Host ""
}

# Get storage account
if (-not $Json) {
    Write-ColorOutput "Getting storage account..." $script:Yellow
}

$storageAccount = az storage account list --resource-group $resourceGroup --query '[0].name' -o tsv

if (-not $storageAccount) {
    Write-ColorOutput "✗ Storage account not found in $resourceGroup" $script:Red
    exit 1
}

if (-not $Json) {
    Write-ColorOutput "✓ Found: $storageAccount" $script:Green
    Write-Host ""
}

# Get storage account key
if (-not $Json) {
    Write-ColorOutput "Getting storage account key..." $script:Yellow
}

$storageKey = az storage account keys list `
    --resource-group $resourceGroup `
    --account-name $storageAccount `
    --query '[0].value' -o tsv

if (-not $storageKey) {
    Write-ColorOutput "✗ Failed to get storage account key" $script:Red
    exit 1
}

# Read cache from blob storage
$containerName = 'servicehealth-cache'
$blobName = 'servicehealth.json'

if (-not $Json) {
    Write-ColorOutput "Reading cache from blob storage..." $script:Yellow
    Write-Host "  Container: $containerName"
    Write-Host "  Blob: $blobName"
    Write-Host ""
}

try {
    # Download to a temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()

    az storage blob download `
        --container-name $containerName `
        --name $blobName `
        --account-name $storageAccount `
        --account-key $storageKey `
        --only-show-errors `
        --file $tempFile `
        --output none

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Failed to read cache blob" $script:Red
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        exit 1
    }

    $cachedData = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
    Remove-Item $tempFile -Force

    if (-not $Json) {
        Write-ColorOutput "✓ Cache read successfully" $script:Green
        Write-Host ""
    }
}
catch {
    Write-ColorOutput "✗ Failed to read or parse cache: $_" $script:Red
    exit 1
}

# Calculate dashboard
$dashboard = Get-ServiceHealthDashboard -CachedData $cachedData -TopCount $TopN

# Output results
if ($Json) {
    $dashboard | ConvertTo-Json -Depth 10
}
else {
    Write-ColorOutput "========================================" $script:Magenta
    Write-ColorOutput "SYSTEM STATUS" $script:Magenta
    Write-ColorOutput "========================================" $script:Magenta
    Write-Host "API Version:        $($dashboard.systemStatus.apiVersion)"
    Write-Host "Cache Last Updated: $($dashboard.systemStatus.cacheLastUpdated)"
    Write-Host "Cache Age:          $($dashboard.systemStatus.cacheAge)"
    Write-Host "Next Update:        $($dashboard.systemStatus.nextUpdate)"

    $healthColor = if ($dashboard.systemStatus.dataHealth -eq 'Healthy') { $script:Green } else { $script:Yellow }
    Write-ColorOutput "Data Health:        $($dashboard.systemStatus.dataHealth)" $healthColor
    Write-Host ""

    Write-ColorOutput "========================================" $script:Magenta
    Write-ColorOutput "STATISTICS" $script:Magenta
    Write-ColorOutput "========================================" $script:Magenta
    Write-Host "Total Events in Cache: $($dashboard.statistics.totalEventsInCache)"

    $activeColor = if ($dashboard.statistics.activeIssues -eq 0) { $script:Green } else { $script:Yellow }
    Write-ColorOutput "Active Issues:         $($dashboard.statistics.activeIssues)" $activeColor
    Write-Host ""

    Write-ColorOutput "Events by Type:" $script:Cyan
    foreach ($item in $dashboard.statistics.eventsByType) {
        Write-Host "  $($item.type): $($item.count)"
    }
    Write-Host ""

    Write-ColorOutput "Events by Status:" $script:Cyan
    foreach ($item in $dashboard.statistics.eventsByStatus) {
        Write-Host "  $($item.status): $($item.count)"
    }
    Write-Host ""

    if ($Detailed) {
        Write-ColorOutput "Events by Level:" $script:Cyan
        foreach ($item in $dashboard.statistics.eventsByLevel) {
            Write-Host "  $($item.level): $($item.count)"
        }
        Write-Host ""
    }

    Write-ColorOutput "Date Range:" $script:Cyan
    Write-Host "  Oldest Event: $($dashboard.statistics.dateRange.oldestEvent)"
    Write-Host "  Newest Event: $($dashboard.statistics.dateRange.newestEvent)"
    Write-Host ""

    Write-ColorOutput "========================================" $script:Magenta
    Write-ColorOutput "TOP AFFECTED (Top $TopN)" $script:Magenta
    Write-ColorOutput "========================================" $script:Magenta

    Write-ColorOutput "Services:" $script:Cyan
    if ($dashboard.topAffected.services.Count -eq 0) {
        Write-Host "  No service data available"
    }
    else {
        foreach ($item in $dashboard.topAffected.services) {
            Write-Host "  $($item.service): $($item.count) event(s)"
        }
    }
    Write-Host ""

    Write-ColorOutput "Regions:" $script:Cyan
    if ($dashboard.topAffected.regions.Count -eq 0) {
        Write-Host "  No region data available"
    }
    else {
        foreach ($item in $dashboard.topAffected.regions) {
            Write-Host "  $($item.region): $($item.count) event(s)"
        }
    }
    Write-Host ""

    Write-ColorOutput "========================================" $script:Magenta
    Write-ColorOutput "HISTORICAL TRENDS" $script:Magenta
    Write-ColorOutput "========================================" $script:Magenta
    Write-Host "Last 24 Hours: $($dashboard.trends.last24Hours) event(s)"
    Write-Host "Last 7 Days:   $($dashboard.trends.last7Days) event(s)"
    Write-Host "Last 30 Days:  $($dashboard.trends.last30Days) event(s)"
    Write-Host ""

    Write-ColorOutput "========================================" $script:Green
    Write-ColorOutput "Dashboard Complete" $script:Green
    Write-ColorOutput "========================================" $script:Green
}
