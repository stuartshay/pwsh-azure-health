using namespace System.Net

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Test mocks use parameters for filter matching')]
param()

BeforeAll {
    $testRoot = $PSScriptRoot
    if (-not $testRoot) {
        $testRoot = $pwd.Path
    }
    $projectRoot = Split-Path $testRoot -Parent
    $srcRoot = Join-Path -Path $projectRoot -ChildPath 'src'

    # Define HttpResponseContext type for testing (normally provided by Azure Functions runtime)
    if (-not ([System.Management.Automation.PSTypeName]'HttpResponseContext').Type) {
        Add-Type -TypeDefinition @'
            public class HttpResponseContext {
                public int StatusCode { get; set; }
                public object Body { get; set; }
                public System.Collections.Hashtable Headers { get; set; }
            }
'@
    }

    # Load shared modules
    Get-ChildItem -Path (Join-Path -Path $srcRoot -ChildPath 'shared' -AdditionalChildPath 'Modules') -Filter '*.psm1' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Import-Module $_.FullName -Force
    }

    # Dot source shared scripts
    Get-ChildItem -Path (Join-Path -Path $srcRoot -ChildPath 'shared' -AdditionalChildPath 'Scripts') -Filter '*.ps1' -File -ErrorAction SilentlyContinue | ForEach-Object {
        . $_.FullName
    }

    # Dot source function scripts
    . (Join-Path -Path $srcRoot -ChildPath 'GetServiceHealth' -AdditionalChildPath 'run.ps1')
    . (Join-Path -Path $srcRoot -ChildPath 'GetServiceHealthTimer' -AdditionalChildPath 'run.ps1')
}

Describe 'GetServiceHealth HTTP function' {
    BeforeEach {
        Remove-Item Env:CACHE_CONTAINER -ErrorAction SilentlyContinue
    }

    It 'returns 204 when no cache exists' {
        Mock -CommandName Get-BlobCacheItem -MockWith { return $null }

        $response = Invoke-ServiceHealthRequest -Request ([pscustomobject]@{}) -TriggerMetadata $null

        $response.StatusCode | Should -Be ([HttpStatusCode]::NoContent)
        $response.Body | Should -BeNullOrEmpty
    }

    It 'returns cached payload when available' {
        $cachedPayload = [pscustomobject]@{
            subscriptionId = '00000000-0000-0000-0000-000000000000'
            cachedAt       = (Get-Date).ToString('o')
            events         = @()
        }

        Mock -CommandName Get-BlobCacheItem -MockWith { return $cachedPayload }

        $response = Invoke-ServiceHealthRequest -Request ([pscustomobject]@{}) -TriggerMetadata $null

        $response.StatusCode | Should -Be ([HttpStatusCode]::OK)
        $response.Body.subscriptionId | Should -Be $cachedPayload.subscriptionId
    }
}

Describe 'GetServiceHealthTimer function' {
    BeforeEach {
        $env:AZURE_SUBSCRIPTION_ID = '00000000-0000-0000-0000-000000000000'
        Remove-Item Env:CACHE_CONTAINER -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Env:AZURE_SUBSCRIPTION_ID -ErrorAction SilentlyContinue
    }

    It 'writes cache when new events are returned' {
        $existingCache = [pscustomobject]@{
            subscriptionId = $env:AZURE_SUBSCRIPTION_ID
            cachedAt       = (Get-Date).AddMinutes(-15).ToString('o')
            lastEventTime  = (Get-Date).AddMinutes(-15).ToString('o')
            trackingIds    = @('track-1')
            events         = @(
                [pscustomobject]@{
                    Id             = 'event-1'
                    TrackingId     = 'track-1'
                    Title          = 'Existing event'
                    LastUpdateTime = (Get-Date).AddHours(-1)
                }
            )
        }

        $newServiceEvents = @(
            [pscustomobject]@{
                Id             = 'event-1'
                TrackingId     = 'track-1'
                Title          = 'Existing event update'
                LastUpdateTime = (Get-Date).AddMinutes(-5)
            },
            [pscustomobject]@{
                Id             = 'event-2'
                TrackingId     = 'track-2'
                Title          = 'New event'
                LastUpdateTime = (Get-Date).AddMinutes(-2)
            }
        )

        $script:capturedContent = $null

        Mock -CommandName Get-BlobCacheItem -MockWith { return $existingCache }
        Mock -CommandName Get-ServiceHealthEvents -MockWith {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Parameters used by mock filter')]
            param($SubscriptionId, $StartTime)
            return $newServiceEvents
        }
        Mock -CommandName Set-BlobCacheItem -MockWith {
            param($ContainerName, $BlobName, $Content)
            $script:capturedContent = $Content
        }

        Invoke-GetServiceHealthTimer -Timer $null

        Assert-MockCalled -CommandName Set-BlobCacheItem -Times 1 -Exactly
        $script:capturedContent | Should -Not -BeNullOrEmpty
        $script:capturedContent.events | Should -HaveCount 2
        $script:capturedContent.trackingIds | Should -Contain 'track-2'
    }

    It 'does not write cache when no new events are returned' {
        $existingCache = [pscustomobject]@{
            subscriptionId = $env:AZURE_SUBSCRIPTION_ID
            cachedAt       = (Get-Date).AddMinutes(-15).ToString('o')
            lastEventTime  = (Get-Date).AddMinutes(-15).ToString('o')
            trackingIds    = @('track-1')
            events         = @(
                [pscustomobject]@{
                    Id             = 'event-1'
                    TrackingId     = 'track-1'
                    Title          = 'Existing event'
                    LastUpdateTime = (Get-Date).AddHours(-1)
                }
            )
        }

        $serviceEvents = @(
            [pscustomobject]@{
                Id             = 'event-1'
                TrackingId     = 'track-1'
                Title          = 'Existing event'
                LastUpdateTime = (Get-Date).AddMinutes(-5)
            }
        )

        Mock -CommandName Get-BlobCacheItem -MockWith { return $existingCache }
        Mock -CommandName Get-ServiceHealthEvents -MockWith {
            param($SubscriptionId, $StartTime)
            return $serviceEvents
        }
        Mock -CommandName Set-BlobCacheItem -MockWith { }

        Invoke-GetServiceHealthTimer -Timer $null

        Assert-MockCalled -CommandName Set-BlobCacheItem -Times 0 -Exactly
    }
}
