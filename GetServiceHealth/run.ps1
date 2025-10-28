using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request for Azure Service Health."

# Interact with query parameters or the body of the request.
$subscriptionId = $Request.Query.SubscriptionId
if (-not $subscriptionId) {
    $subscriptionId = $Request.Body.SubscriptionId
}

# If no subscription ID provided, try to use the environment variable
if (-not $subscriptionId) {
    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID
}

$status = [HttpStatusCode]::OK
$body = @{}

try {
    if (-not $subscriptionId) {
        $status = [HttpStatusCode]::BadRequest
        $body = @{
            error = "Please pass a SubscriptionId on the query string or in the request body, or configure AZURE_SUBSCRIPTION_ID in application settings."
        }
    }
    else {
        Write-Host "Retrieving Azure Service Health for subscription: $subscriptionId"
        
        # Set the context to the specified subscription
        Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
        
        # Get Service Health events
        # Query for active service health events from the last 7 days
        $startTime = (Get-Date).AddDays(-7)
        
        $query = @"
ServiceHealthResources
| where type == 'microsoft.resourcehealth/events'
| where properties.eventType == 'ServiceIssue' or properties.eventType == 'PlannedMaintenance'
| where properties.status == 'Active' or todatetime(properties.lastUpdateTime) >= datetime('$($startTime.ToString('yyyy-MM-ddTHH:mm:ssZ'))')
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

        Write-Host "Executing Resource Graph query for Service Health events..."
        $results = Search-AzGraph -Query $query -Subscription $subscriptionId
        
        $body = @{
            subscriptionId = $subscriptionId
            retrievedAt = (Get-Date).ToString('o')
            eventCount = $results.Count
            events = $results | ForEach-Object {
                @{
                    id = $_.id
                    eventType = $_.eventType
                    status = $_.status
                    title = $_.title
                    summary = $_.summary
                    level = $_.level
                    impactedServices = $_.impactedServices
                    lastUpdateTime = $_.lastUpdateTime
                }
            }
        }
        
        Write-Host "Successfully retrieved $($results.Count) Service Health events."
    }
}
catch {
    Write-Host "Error occurred: $($_.Exception.Message)"
    $status = [HttpStatusCode]::InternalServerError
    $body = @{
        error = "An error occurred while retrieving Azure Service Health data."
        details = $_.Exception.Message
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $status
    Body = $body
    Headers = @{
        "Content-Type" = "application/json"
    }
})
