function New-HttpJsonResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpStatusCode]$StatusCode,

        [Parameter(Mandatory = $true)]
        $Body
    )

    return [HttpResponseContext]@{
        StatusCode = $StatusCode
        Body       = $Body
        Headers    = @{
            'Content-Type' = 'application/json'
        }
    }
}
