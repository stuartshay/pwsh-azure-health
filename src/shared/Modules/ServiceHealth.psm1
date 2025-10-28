function Get-ServiceHealthEvents {
    [CmdletBinding()]
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
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

    $isoStart = $StartTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
    $query = @"
ServiceHealthResources
| where type == 'microsoft.resourcehealth/events'
| where properties.eventType == 'ServiceIssue' or properties.eventType == 'PlannedMaintenance'
| where properties.status == 'Active' or todatetime(properties.lastUpdateTime) >= datetime('$isoStart')
| project
    id,
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
    $results = Search-AzGraph -Query $query -Subscription $SubscriptionId -ErrorAction Stop

    return $results | ForEach-Object {
        [pscustomobject]@{
            Id               = $_.id
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
