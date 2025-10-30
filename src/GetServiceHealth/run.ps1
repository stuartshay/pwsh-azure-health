using namespace System.Net

param($Request, $TriggerMetadata)

function Invoke-ServiceHealthRequest {
    [CmdletBinding()]
    param(
        $Request,
        $TriggerMetadata
    )

    Write-Host "Processing Azure Service Health cache request."

    $containerName = if ($env:CACHE_CONTAINER) { $env:CACHE_CONTAINER } else { 'servicehealth-cache' }
    $blobName = 'servicehealth.json'

    try {
        $cache = Get-BlobCacheItem -ContainerName $containerName -BlobName $blobName

        if (-not $cache) {
            Write-Host "No cached Service Health payload was found."
            return [HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::NoContent
                Body       = $null
                Headers    = @{}
            }
        }

        Write-Host "Returning cached Service Health payload."
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
