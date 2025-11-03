param($Timer)

<#
.SYNOPSIS
    Timer-triggered function to poll Azure Service Health events.
.PARAMETER Timer
    The timer trigger metadata.
#>
function Invoke-GetServiceHealthTimer {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Timer', Justification = 'Required by Azure Functions runtime')]
    param($Timer)

    Write-Information "GetServiceHealthTimer triggered at $(Get-Date -Format o)." -InformationAction Continue

    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID
    if (-not $subscriptionId) {
        Write-Error "AZURE_SUBSCRIPTION_ID is not configured; skipping poll."
        return
    }

    Write-Information "Configuration: SubscriptionId=$subscriptionId" -InformationAction Continue

    $containerName = if ($env:CACHE_CONTAINER) { $env:CACHE_CONTAINER } else { 'servicehealth-cache' }
    $blobName = 'servicehealth.json'

    Write-Information "Cache configuration: Container=$containerName, Blob=$blobName" -InformationAction Continue

    $cache = $null
    try {
        Write-Information "Reading existing cache..." -InformationAction Continue
        $cache = Get-BlobCacheItem -ContainerName $containerName -BlobName $blobName
        if ($cache) {
            $eventCount = if ($cache.events) { $cache.events.Count } else { 0 }
            Write-Information "Found existing cache with $eventCount event(s), last updated: $($cache.lastEventTime)" -InformationAction Continue
        } else {
            Write-Information "No existing cache found." -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Unable to read existing cache: $($_.Exception.Message)"
    }

    $existingEvents = @()
    $knownKeys = @{}

    if ($cache -and $cache.events) {
        $existingEvents = @($cache.events)
        foreach ($healthEvent in $existingEvents) {
            $key = if ($healthEvent.TrackingId) { $healthEvent.TrackingId } elseif ($healthEvent.Id) { $healthEvent.Id } else { $null }
            if ($key -and -not $knownKeys.ContainsKey($key)) {
                $knownKeys[$key] = $true
            }
        }
    }

    $startTime = (Get-Date).AddDays(-7)
    if ($cache -and $cache.lastEventTime) {
        try {
            $startTime = [datetime]::Parse($cache.lastEventTime).ToUniversalTime()
        }
        catch {
            Write-Warning "Unable to parse lastEventTime from cache. Using default window."
        }
    }

    Write-Information "Querying Service Health events from $($startTime.ToString('o'))..." -InformationAction Continue

    $events = @()
    try {
        $events = Get-ServiceHealthEvents -SubscriptionId $subscriptionId -StartTime $startTime
        Write-Information "Retrieved $($events.Count) event(s) from Azure Resource Graph." -InformationAction Continue
    }
    catch {
        Write-Error "Failed to query Service Health events: $($_.Exception.Message)"
        return
    }

    if (-not $events) {
        Write-Information "No Service Health events returned for subscription $subscriptionId." -InformationAction Continue
        return
    }

    $newEvents = New-Object 'System.Collections.Generic.List[object]'
    foreach ($healthEvent in $events) {
        $key = if ($healthEvent.TrackingId) { $healthEvent.TrackingId } elseif ($healthEvent.Id) { $healthEvent.Id } else { [guid]::NewGuid().ToString() }
        if (-not $knownKeys.ContainsKey($key)) {
            $knownKeys[$key] = $true
            $newEvents.Add($healthEvent)
        }
    }

    Write-Information "Identified $($newEvents.Count) new event(s) not in cache." -InformationAction Continue

    if (-not $newEvents.Count) {
        Write-Information "No new Service Health events detected for subscription $subscriptionId." -InformationAction Continue
        return
    }

    <#
    .SYNOPSIS
        Gets normalized timestamp from event.
    .PARAMETER value
        The timestamp value.
    #>
    function Get-EventTimestamp {
        param($value)

        if ($value -is [datetime]) {
            return $value.ToUniversalTime()
        }

        if ($null -ne $value) {
            return [datetime]::Parse($value.ToString()).ToUniversalTime()
        }

        return (Get-Date).ToUniversalTime()
    }

    $combined = @($newEvents + $existingEvents) | Where-Object { $_ }
    $sorted = $combined | Sort-Object -Property @{ Expression = { Get-EventTimestamp $_.LastUpdateTime } } -Descending

    $deduped = @()
    $seen = @{}
    foreach ($healthEvent in $sorted) {
        $key = if ($healthEvent.TrackingId) { $healthEvent.TrackingId } elseif ($healthEvent.Id) { $healthEvent.Id } else { [guid]::NewGuid().ToString() }
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $deduped += $healthEvent
        }
    }

    Write-Information "Deduplicated to $($deduped.Count) total unique event(s)." -InformationAction Continue

    $latestUpdate = if ($deduped) {
        (Get-EventTimestamp $deduped[0].LastUpdateTime).ToString('o')
    }
    else {
        (Get-Date).ToUniversalTime().ToString('o')
    }

    $payload = [ordered]@{
        subscriptionId = $subscriptionId
        cachedAt       = (Get-Date).ToUniversalTime().ToString('o')
        lastEventTime  = $latestUpdate
        trackingIds    = $deduped | ForEach-Object { if ($_.TrackingId) { $_.TrackingId } elseif ($_.Id) { $_.Id } } | Where-Object { $_ }
        events         = $deduped
    }

    try {
        Write-Information "Writing cache to blob storage..." -InformationAction Continue
        Set-BlobCacheItem -ContainerName $containerName -BlobName $blobName -Content $payload
        Write-Information "Successfully cached $($newEvents.Count) new Service Health event(s) for subscription $subscriptionId." -InformationAction Continue
        Write-Information "Cache updated with $($deduped.Count) total event(s), latest timestamp: $latestUpdate" -InformationAction Continue
    }
    catch {
        Write-Error "Failed to write Service Health cache: $($_.Exception.Message)"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-GetServiceHealthTimer -Timer $Timer
}
