using namespace System.Net

param($Request, $TriggerMetadata)

<#
.SYNOPSIS
    Provides a comprehensive dashboard of Azure Service Health analytics.
.DESCRIPTION
    Retrieves cached Service Health data and calculates comprehensive statistics
    including event counts, top affected services/regions, historical trends, and cache metrics.
.PARAMETER Request
    The HTTP request object.
.PARAMETER TriggerMetadata
    Metadata about the trigger.
#>
function Invoke-HealthDashboardRequest {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Request', Justification = 'Required by Azure Functions runtime')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'TriggerMetadata', Justification = 'Required by Azure Functions runtime')]
    param(
        $Request,
        $TriggerMetadata
    )

    Write-Information "Processing Health Dashboard request." -InformationAction Continue

    $containerName = if ($env:CACHE_CONTAINER) { $env:CACHE_CONTAINER } else { 'servicehealth-cache' }
    $blobName = 'servicehealth.json'

    try {
        $cache = Get-BlobCacheItem -ContainerName $containerName -BlobName $blobName

        if (-not $cache) {
            Write-Information "No cached Service Health payload found." -InformationAction Continue
            return New-HttpJsonResponse -StatusCode ([HttpStatusCode]::NoContent) -Body @{
                error = 'No cached data available.'
            }
        }

        # Get TopN from query parameter, default to 5
        $topN = 5
        if ($Request.Query.topN) {
            $topN = [int]$Request.Query.topN
        }

        Write-Information "Calculating dashboard with TopN=$topN" -InformationAction Continue

        $dashboard = Get-ServiceHealthDashboard -CachedData $cache -TopCount $topN

        Write-Information "Returning Health Dashboard payload." -InformationAction Continue
        return New-HttpJsonResponse -StatusCode ([HttpStatusCode]::OK) -Body $dashboard
    }
    catch {
        Write-Error "Failed to generate Health Dashboard: $($_.Exception.Message)"
        return New-HttpJsonResponse -StatusCode ([HttpStatusCode]::InternalServerError) -Body @{
            error = 'Unable to generate dashboard data.'
        }
    }
}

function Get-ServiceHealthDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $CachedData,

        [int]$TopCount = 5
    )

    $now = [DateTime]::UtcNow
    $events = $CachedData.events

    # Calculate cache metrics
    $lastQueryTime = if ($CachedData.cachedAt) {
        [DateTime]::Parse($CachedData.cachedAt)
    }
    else {
        $null
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
    foreach ($event in $events) {
        if ($event.ImpactedServices) {
            foreach ($svc in $event.ImpactedServices) {
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
    foreach ($event in $events) {
        if ($event.ImpactedServices) {
            foreach ($svc in $event.ImpactedServices) {
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

    # Calculate time-based trends
    $last24Hours = $events | Where-Object {
        $eventTime = [DateTime]::Parse($_.LastUpdateTime)
        ($now - $eventTime).TotalHours -le 24
    } | Measure-Object | Select-Object -ExpandProperty Count

    $last7Days = $events | Where-Object {
        $eventTime = [DateTime]::Parse($_.LastUpdateTime)
        ($now - $eventTime).TotalDays -le 7
    } | Measure-Object | Select-Object -ExpandProperty Count

    $last30Days = $events | Where-Object {
        $eventTime = [DateTime]::Parse($_.LastUpdateTime)
        ($now - $eventTime).TotalDays -le 30
    } | Measure-Object | Select-Object -ExpandProperty Count

    # Find oldest and newest events
    $eventTimes = $events | ForEach-Object { [DateTime]::Parse($_.LastUpdateTime) }
    $oldestEvent = if ($eventTimes) { ($eventTimes | Measure-Object -Minimum).Minimum } else { $null }
    $newestEvent = if ($eventTimes) { ($eventTimes | Measure-Object -Maximum).Maximum } else { $null }

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

if ($MyInvocation.InvocationName -ne '.') {
    $response = Invoke-HealthDashboardRequest -Request $Request -TriggerMetadata $TriggerMetadata
    Push-OutputBinding -Name Response -Value $response
}
