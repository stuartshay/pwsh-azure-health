$modulePath = Join-Path $PSScriptRoot '..' '..' 'src' 'shared' 'Modules' 'ServiceHealth.psm1'
Import-Module $modulePath -Force

describe 'Get-ServiceHealthEvents' -Tag 'unit' {
    BeforeEach {
        Mock -CommandName Set-AzContext -MockWith { $null }
        Mock -CommandName Search-AzGraph -MockWith {
            @(
                [pscustomobject]@{
                    id               = '/subscriptions/0000/resourceGroups/rg/providers/microsoft.resourcehealth/events/1'
                    eventType        = 'ServiceIssue'
                    status           = 'Active'
                    title            = 'Test issue'
                    summary          = 'Service issue summary'
                    level            = 'Warning'
                    impactedServices = @('Compute')
                    lastUpdateTime   = [datetime]::UtcNow
                }
            )
        }
    }

    It 'returns projected event objects' {
        $subscription = '00000000-0000-0000-0000-000000000000'
        $events = Get-ServiceHealthEvents -SubscriptionId $subscription -DaysBack 3

        $events | Should -Not -BeNullOrEmpty
        $events | Should -HaveCount 1
        $events[0].Title | Should -Be 'Test issue'
        $events[0].ImpactedServices | Should -Contain 'Compute'

        Assert-MockCalled -CommandName Set-AzContext -Times 1 -Exactly -ParameterFilter { $SubscriptionId -eq $subscription }
        Assert-MockCalled -CommandName Search-AzGraph -Times 1 -Exactly -ParameterFilter { $Subscription -eq $subscription }
    }
}
