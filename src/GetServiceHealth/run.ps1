using namespace System.Net

param($Request, $TriggerMetadata)

Write-Host "Processing Azure Service Health request."

$subscriptionId = $Request.Query.SubscriptionId
if (-not $subscriptionId -and $Request.Body) {
    if ($Request.Body -is [string] -and $Request.Body.Trim().StartsWith('{', [System.StringComparison]::Ordinal)) {
        try {
            $parsedBody = $Request.Body | ConvertFrom-Json -ErrorAction Stop
            $subscriptionId = $parsedBody.SubscriptionId
        }
        catch {
            Write-Warning "Unable to parse request body as JSON: $($_.Exception.Message)"
        }
    }
    elseif ($Request.Body -isnot [string] -and $Request.Body.PSObject.Properties['SubscriptionId']) {
        $subscriptionId = $Request.Body.SubscriptionId
    }
}

if (-not $subscriptionId) {
    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID
}

try {
    if (-not $subscriptionId) {
        $message = "Please pass a SubscriptionId on the query string or in the request body, or configure AZURE_SUBSCRIPTION_ID in application settings."
        $response = New-HttpJsonResponse -StatusCode ([HttpStatusCode]::BadRequest) -Body @{ error = $message }
    }
    else {
        Write-Host "Retrieving Azure Service Health for subscription: $subscriptionId"

        $events = Get-ServiceHealthEvents -SubscriptionId $subscriptionId

        $body = [ordered]@{
            subscriptionId = $subscriptionId
            retrievedAt    = (Get-Date).ToString('o')
            eventCount     = @($events).Count
            events         = $events
        }

        Write-Host "Successfully retrieved $(@($events).Count) Service Health events."
        $response = New-HttpJsonResponse -StatusCode ([HttpStatusCode]::OK) -Body $body
    }
}
catch {
    Write-Error "Error occurred while retrieving Service Health: $($_.Exception.Message)"
    $response = New-HttpJsonResponse -StatusCode ([HttpStatusCode]::InternalServerError) -Body @{
        error   = "An error occurred while retrieving Azure Service Health data."
        details = $_.Exception.Message
    }
}

Push-OutputBinding -Name Response -Value $response
