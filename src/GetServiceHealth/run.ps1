using namespace System.Net

param($Request, $TriggerMetadata)

<#
.SYNOPSIS
    Processes Azure Service Health cache requests.
.DESCRIPTION
    Retrieves cached Service Health data from blob storage and returns it via HTTP response.
.PARAMETER Request
    The HTTP request object.
.PARAMETER TriggerMetadata
    Metadata about the trigger.
#>
function Invoke-ServiceHealthRequest {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Request', Justification = 'Required by Azure Functions runtime')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'TriggerMetadata', Justification = 'Required by Azure Functions runtime')]
    param(
        $Request,
        $TriggerMetadata
    )

    Write-Information "Processing Azure Service Health cache request." -InformationAction Continue

    $containerName = if ($env:CACHE_CONTAINER) { $env:CACHE_CONTAINER } else { 'servicehealth-cache' }
    $blobName = 'servicehealth.json'

    try {
        $cache = Get-BlobCacheItem -ContainerName $containerName -BlobName $blobName

        if (-not $cache) {
            Write-Information "No cached Service Health payload was found." -InformationAction Continue
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NoContent
                Body       = $null
                Headers    = @{}
            }
        }

        Write-Information "Returning cached Service Health payload." -InformationAction Continue
        return New-HttpJsonResponse -StatusCode ([HttpStatusCode]::OK) -Body $cache
    }
    catch {
        Write-Error "Failed to read cached Service Health payload: $($_.Exception.Message)"
        return New-HttpJsonResponse -StatusCode ([HttpStatusCode]::InternalServerError) -Body @{
            error = 'Unable to read cached Service Health data.'
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $response = Invoke-ServiceHealthRequest -Request $Request -TriggerMetadata $TriggerMetadata
    Push-OutputBinding -Name Response -Value $response
}

if ($MyInvocation.InvocationName -ne '.') {
    $response = Invoke-ServiceHealthRequest -Request $Request -TriggerMetadata $TriggerMetadata
    Push-OutputBinding -Name Response -Value $response
}
