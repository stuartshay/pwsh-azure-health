Describe 'HealthCheck Function' -Tag 'unit' {
    BeforeAll {
        # Define HttpResponseContext type for testing (it's only available in Azure Functions runtime)
        if (-not ([System.Management.Automation.PSTypeName]'HttpResponseContext').Type) {
            Add-Type -TypeDefinition @"
                public class HttpResponseContext
                {
                    public int StatusCode { get; set; }
                    public object Body { get; set; }
                    public System.Collections.Hashtable Headers { get; set; }
                }
"@
        }

        # Build path relative to test file location
        $testRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
        $functionPath = Join-Path -Path $testRoot -ChildPath '..' -AdditionalChildPath @('..', 'src', 'HealthCheck', 'run.ps1')
        $functionPath = (Resolve-Path $functionPath).Path

        # Load the function by dot-sourcing the function script
        . $functionPath
    }

    Context 'when function app is healthy' {
        BeforeEach {
            # Mock environment to simulate healthy state
            $env:FUNCTIONS_WORKER_RUNTIME = 'powershell'
        }

        It 'returns 200 OK status code' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.StatusCode | Should -Be 200
        }

        It 'returns healthy status in response body' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Body.status | Should -Be 'healthy'
        }

        It 'includes timestamp in response' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Body.timestamp | Should -Not -BeNullOrEmpty
        }

        It 'includes PowerShell version in response' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Body.version | Should -Not -BeNullOrEmpty
            $response.Body.runtime | Should -Be 'PowerShell'
        }

        It 'sets appropriate headers' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Headers.'Content-Type' | Should -Be 'application/json'
            $response.Headers.'Cache-Control' | Should -Match 'no-cache'
        }
    }

    Context 'when function app configuration is incomplete' {
        BeforeEach {
            # Remove environment variable to simulate degraded state
            Remove-Item env:FUNCTIONS_WORKER_RUNTIME -ErrorAction SilentlyContinue
        }

        AfterEach {
            # Restore environment variable
            $env:FUNCTIONS_WORKER_RUNTIME = 'powershell'
        }

        It 'returns 503 Service Unavailable status code' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.StatusCode | Should -Be 503
        }

        It 'returns degraded status in response body' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Body.status | Should -Be 'degraded'
        }

        It 'includes warnings in response' {
            $mockRequest = @{}
            $mockTriggerMetadata = @{}

            $response = Invoke-HealthCheck -Request $mockRequest -TriggerMetadata $mockTriggerMetadata

            $response.Body.warnings | Should -Not -BeNullOrEmpty
        }
    }
}
