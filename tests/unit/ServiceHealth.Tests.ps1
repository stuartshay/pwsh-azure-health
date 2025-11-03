$modulePath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath @('..', 'src', 'shared', 'Modules', 'ServiceHealth.psm1')
Import-Module $modulePath -Force

Describe 'Get-ServiceHealthEvents' -Tag 'unit' {
    BeforeAll {
        # Check if required Az modules are available
        $script:azAccountsAvailable = Get-Module -ListAvailable -Name Az.Accounts
        $script:azResourceGraphAvailable = Get-Module -ListAvailable -Name Az.ResourceGraph

        if ($script:azAccountsAvailable -and $script:azResourceGraphAvailable) {
            # Import Az modules to ensure cmdlets are available for mocking
            Import-Module Az.Accounts -ErrorAction Stop
            Import-Module Az.ResourceGraph -ErrorAction Stop
        }
    }

    BeforeEach {
        # Mock Get-AzContext to return a valid context (simulates being logged in)
        Mock -CommandName Get-AzContext -ModuleName ServiceHealth -MockWith {
            [pscustomobject]@{
                Subscription = [pscustomobject]@{
                    Id = '00000000-0000-0000-0000-000000000000'
                }
            }
        }

        Mock -CommandName Set-AzContext -ModuleName ServiceHealth -MockWith {
            [pscustomobject]@{
                Subscription = [pscustomobject]@{
                    Id = $SubscriptionId
                }
            }
        }

        Mock -CommandName Search-AzGraph -ModuleName ServiceHealth -MockWith {
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

    It 'returns projected event objects' -Skip:(-not ($script:azAccountsAvailable -and $script:azResourceGraphAvailable)) {
        $subscription = '00000000-0000-0000-0000-000000000000'
        $events = Get-ServiceHealthEvents -SubscriptionId $subscription -DaysBack 3

        $events | Should -Not -BeNullOrEmpty
        $events | Should -HaveCount 1
        $events[0].Title | Should -Be 'Test issue'
        $events[0].ImpactedServices | Should -Contain 'Compute'

        Assert-MockCalled -CommandName Set-AzContext -ModuleName ServiceHealth -Times 1 -Exactly -ParameterFilter { $SubscriptionId -eq $subscription }
        Assert-MockCalled -CommandName Search-AzGraph -ModuleName ServiceHealth -Times 1 -Exactly -ParameterFilter { $Subscription -eq $subscription }
    }
}
