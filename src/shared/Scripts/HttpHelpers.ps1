<#
.SYNOPSIS
    Creates an HTTP JSON response.
.DESCRIPTION
    Constructs an HttpResponseContext object with JSON content type.
.PARAMETER StatusCode
    The HTTP status code.
.PARAMETER Body
    The response body.
#>
function New-HttpJsonResponse {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.HttpStatusCode]$StatusCode,

        [Parameter(Mandatory = $true)]
        $Body
    )

    if ($PSCmdlet.ShouldProcess("HTTP Response", "Create")) {
        return [HttpResponseContext]@{
            StatusCode = $StatusCode
            Body = $Body
            Headers = @{
                'Content-Type' = 'application/json'
            }
        }
    }
}
