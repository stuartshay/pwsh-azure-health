<#
.SYNOPSIS
    Retrieves Azure Service Health events for a specified subscription.

.DESCRIPTION
    The Get-ServiceHealthEvents function queries Azure Resource Graph to retrieve
    Service Health events (Service Issues and Planned Maintenance) for a given subscription.
    Events can be filtered by a time range, either by specifying the number of days back
    or an explicit start time.

.PARAMETER SubscriptionId
    The Azure subscription ID to query for Service Health events. This parameter is required.

.PARAMETER DaysBack
    The number of days to look back for Service Health events. Valid range is 1-90 days.
    Default value is 7 days. This parameter is ignored if StartTime is specified.

.PARAMETER StartTime
    An explicit start time for filtering Service Health events. If not specified,
    the function uses DaysBack to calculate the start time.

.EXAMPLE
    Get-ServiceHealthEvents -SubscriptionId "00000000-0000-0000-0000-000000000000"

    Retrieves Service Health events for the specified subscription from the last 7 days.

.EXAMPLE
    Get-ServiceHealthEvents -SubscriptionId "00000000-0000-0000-0000-000000000000" -DaysBack 30

    Retrieves Service Health events for the specified subscription from the last 30 days.

.EXAMPLE
    Get-ServiceHealthEvents -SubscriptionId "00000000-0000-0000-0000-000000000000" -StartTime (Get-Date).AddDays(-14)

    Retrieves Service Health events for the specified subscription starting from 14 days ago.

.OUTPUTS
    PSCustomObject
    Returns an array of custom objects with the following properties:
    - Id: The event resource ID
    - EventType: ServiceIssue or PlannedMaintenance
    - Status: Current status of the event
    - Title: Event title
    - Summary: Event summary description
    - Level: Severity level
    - ImpactedServices: List of affected Azure services
    - LastUpdateTime: Last time the event was updated
#>
function Get-ServiceHealthEvents {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Events is the appropriate plural noun for this cmdlet')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,

        [Parameter()]
        [ValidateRange(1, 90)]
        [int]$DaysBack = 7,

        [Parameter()]
        [datetime]$StartTime
    )

    if (-not $PSBoundParameters.ContainsKey('StartTime')) {
        $StartTime = (Get-Date).AddDays(-1 * $DaysBack)
    }

    Write-Verbose "Setting Azure context to subscription '$SubscriptionId'."
    try {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error "Failed to set Azure context for subscription '$SubscriptionId': $($_.Exception.Message)"
        throw
    }

    $isoStart = $StartTime.ToUniversalTime().ToString('o')
    $query = @"
ServiceHealthResources
| where type == 'microsoft.resourcehealth/events'
| where properties.eventType == 'ServiceIssue' or properties.eventType == 'PlannedMaintenance'
| where properties.status == 'Active' or todatetime(properties.lastUpdateTime) >= datetime('$isoStart')
| project
    id,
    trackingId = properties.trackingId,
    eventType = properties.eventType,
    status = properties.status,
    title = properties.title,
    summary = properties.summary,
    level = properties.level,
    impactedServices = properties.impact,
    lastUpdateTime = properties.lastUpdateTime
| order by lastUpdateTime desc
"@

    Write-Verbose "Executing Resource Graph query for Service Health events."
    try {
        $results = Search-AzGraph -Query $query -Subscription $SubscriptionId -ErrorAction Stop
    }
    catch {
        Write-Error "Resource Graph query failed: $($_.Exception.Message)"
        Write-Verbose "Query: $query"
        throw
    }

    return $results | ForEach-Object {
        [pscustomobject]@{
            Id               = $_.id
            TrackingId       = $_.trackingId
            EventType        = $_.eventType
            Status           = $_.status
            Title            = $_.title
            Summary          = $_.summary
            Level            = $_.level
            ImpactedServices = $_.impactedServices
            LastUpdateTime   = $_.lastUpdateTime
        }
    }
}

Export-ModuleMember -Function Get-ServiceHealthEvents
