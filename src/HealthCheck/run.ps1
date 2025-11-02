using namespace System.Net

param($Request, $TriggerMetadata)

<#
.SYNOPSIS
    Health check endpoint for Azure Function App.
.DESCRIPTION
    Provides a simple health check endpoint that verifies the function app is running
    and can respond to requests. This endpoint requires no authentication and performs
    minimal checks to ensure fast response times.
.PARAMETER Request
    The HTTP request object.
.PARAMETER TriggerMetadata
    Metadata about the trigger.
#>
function Invoke-HealthCheck {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Request', Justification = 'Required by Azure Functions runtime')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'TriggerMetadata', Justification = 'Required by Azure Functions runtime')]
    param(
        $Request,
        $TriggerMetadata
    )

    Write-Information "Health check requested." -InformationAction Continue

    # Basic health check - verify PowerShell runtime is working
    $healthStatus = @{
        status    = "healthy"
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        version   = $PSVersionTable.PSVersion.ToString()
        runtime   = "PowerShell"
    }

    # Check if we can access environment variables (basic function app configuration check)
    $hasConfig = $null -ne $env:FUNCTIONS_WORKER_RUNTIME

    if (-not $hasConfig) {
        Write-Warning "Function app configuration may be incomplete."
        $healthStatus.status = "degraded"
        $healthStatus.warnings = @("Configuration incomplete")
    }

    # Return appropriate status code
    $statusCode = if ($healthStatus.status -eq "healthy") {
        [HttpStatusCode]::OK
    }
    else {
        [HttpStatusCode]::ServiceUnavailable
    }

    return [HttpResponseContext]@{
        StatusCode = $statusCode
        Body       = $healthStatus
        Headers    = @{
            'Content-Type' = 'application/json'
            'Cache-Control' = 'no-cache, no-store, must-revalidate'
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $response = Invoke-HealthCheck -Request $Request -TriggerMetadata $TriggerMetadata
    Push-OutputBinding -Name Response -Value $response
}
