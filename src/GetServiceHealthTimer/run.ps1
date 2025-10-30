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

    $containerName = if ($env:CACHE_CONTAINER) { $env:CACHE_CONTAINER } else { 'servicehealth-cache' }
    $blobName = 'servicehealth.json'

    $cache = $null
    try {
        $cache = Get-BlobCacheItem -ContainerName $containerName -BlobName $blobName
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

    $events = @()
    try {
        $events = Get-ServiceHealthEvents -SubscriptionId $subscriptionId -StartTime $startTime
    }
    catch {
        Write-Error "Failed to query Service Health events: $($_.Exception.Message)"
        return
    }

    if (-not $events) {
        Write-Information "No Service Health events returned for subscription $subscriptionId." -InformationAction Continue
        return
    }

    $newEvents = @()
    foreach ($healthEvent in $events) {
        $key = if ($healthEvent.TrackingId) { $healthEvent.TrackingId } elseif ($healthEvent.Id) { $healthEvent.Id } else { [guid]::NewGuid().ToString() }
        if (-not $knownKeys.ContainsKey($key)) {
            $knownKeys[$key] = $true
            $newEvents += $healthEvent
        }
    }

    if (-not $newEvents) {
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

    $latestUpdate = if ($deduped) {
        (Get-EventTimestamp $deduped[0].LastUpdateTime).ToString('o')
    }
    else {
        (Get-Date).ToUniversalTime().ToString('o')
    }

    $payload = [ordered]@{
        subscriptionId = $subscriptionId
        cachedAt = (Get-Date).ToUniversalTime().ToString('o')
        lastEventTime = $latestUpdate
        trackingIds = $deduped | ForEach-Object { if ($_.TrackingId) { $_.TrackingId } elseif ($_.Id) { $_.Id } } | Where-Object { $_ }
        events = $deduped
    }

    try {
        Set-BlobCacheItem -ContainerName $containerName -BlobName $blobName -Content $payload
        Write-Information "Cached $($newEvents.Count) new Service Health event(s) for subscription $subscriptionId." -InformationAction Continue
    }
    catch {
        Write-Error "Failed to write Service Health cache: $($_.Exception.Message)"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-GetServiceHealthTimer -Timer $Timer
}
