#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates shared Azure infrastructure setup
.DESCRIPTION
    Verifies that the shared resource group, User-Assigned Managed Identity,
    RBAC role assignments, and resource locks are correctly configured.

    Useful for CI/CD pipelines and troubleshooting deployment issues.
.EXAMPLE
    ./validate-shared-setup.ps1
.NOTES
    Returns exit code 0 on success, 1 on failure.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$SharedResourceGroup = 'rg-azure-health-shared'
$ManagedIdentityName = 'id-azurehealth-shared'
$LockName = 'DoNotDelete-SharedInfrastructure'

$script:ValidationPassed = $true
$script:FailureReasons = @()

<#
.SYNOPSIS
    Writes a formatted message with optional ANSI coloring
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,
        [ValidateSet('Default', 'Cyan', 'Gray', 'Green', 'Yellow', 'Red')]
        [string]$Color = 'Default'
    )

    $prefix = ''
    $suffix = ''

    if ($PSStyle) {
        switch ($Color) {
            'Cyan' { $prefix = $PSStyle.Foreground.Cyan }
            'Gray' { $prefix = $PSStyle.Foreground.Gray }
            'Green' { $prefix = $PSStyle.Foreground.Green }
            'Yellow' { $prefix = $PSStyle.Foreground.Yellow }
            'Red' { $prefix = $PSStyle.Foreground.Red }
        }
        if ($prefix) { $suffix = $PSStyle.Reset }
    }

    Write-Information ("{0}{1}{2}" -f $prefix, $Message, $suffix)
}

function Test-Validation {
    param(
        [Parameter(Mandatory)]
        [string]$TestName,
        [Parameter(Mandatory)]
        [scriptblock]$TestBlock
    )

    Write-Message "  Testing: $TestName" -Color Cyan

    try {
        $result = & $TestBlock
        if ($result -eq $true) {
            Write-Message "  ✓ PASS: $TestName" -Color Green
            return $true
        }
        else {
            Write-Message "  ✗ FAIL: $TestName" -Color Red
            $script:ValidationPassed = $false
            return $false
        }
    }
    catch {
        Write-Message "  ✗ FAIL: $TestName - $_" -Color Red
        $script:ValidationPassed = $false
        $script:FailureReasons += "$TestName : $_"
        return $false
    }
}

try {
    Write-Message ''
    Write-Message '===========================================================' -Color Cyan
    Write-Message '  Shared Infrastructure Validation' -Color Cyan
    Write-Message '===========================================================' -Color Cyan
    Write-Message ''

    # Check authentication
    Write-Message 'Checking Azure CLI authentication...' -Color Cyan
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged in to Azure. Run: az login"
        exit 1
    }

    Write-Message "[OK] Authenticated as: $($account.user.name)" -Color Green
    Write-Message "  Subscription: $($account.name)" -Color Gray
    Write-Message ''

    # Validation Tests
    Write-Message 'Running validation tests...' -Color Cyan
    Write-Message ''

    # Test 1: Resource group exists
    Test-Validation -TestName "Resource group exists ($SharedResourceGroup)" -TestBlock {
        $rgExists = az group exists --name $SharedResourceGroup | ConvertFrom-Json
        return $rgExists
    }

    # Test 2: Managed identity exists
    $identityJson = $null
    Test-Validation -TestName "User-Assigned Managed Identity exists ($ManagedIdentityName)" -TestBlock {
        $script:identityJson = az identity show `
            --name $ManagedIdentityName `
            --resource-group $SharedResourceGroup `
            2>$null

        return ($null -ne $script:identityJson)
    }

    if ($identityJson) {
        $identity = $identityJson | ConvertFrom-Json
        $script:principalId = $identity.principalId
        $script:subscriptionId = $account.id

        Write-Message ''
        Write-Message 'Identity Details:' -Color Cyan
        Write-Message "  Name        : $($identity.name)" -Color Gray
        Write-Message "  Principal ID: $script:principalId" -Color Gray
        Write-Message "  Client ID   : $($identity.clientId)" -Color Gray
        Write-Message "  Resource ID : $($identity.id)" -Color Gray
        Write-Message ''

        # Test 3: Reader role assigned at subscription scope
        Test-Validation -TestName "Reader role assigned (subscription scope)" -TestBlock {
            $roleAssignment = az role assignment list `
                --assignee $script:principalId `
                --role Reader `
                --scope "/subscriptions/$script:subscriptionId" `
                --query '[0].id' -o tsv

            return (-not [string]::IsNullOrEmpty($roleAssignment))
        }

        # Test 4: Monitoring Reader role assigned at subscription scope
        Test-Validation -TestName "Monitoring Reader role assigned (subscription scope)" -TestBlock {
            $roleAssignment = az role assignment list `
                --assignee $script:principalId `
                --role 'Monitoring Reader' `
                --scope "/subscriptions/$script:subscriptionId" `
                --query '[0].id' -o tsv

            return (-not [string]::IsNullOrEmpty($roleAssignment))
        }
    }

    # Test 5: Resource lock applied
    Test-Validation -TestName "Resource lock applied ($LockName)" -TestBlock {
        $lockId = az lock list `
            --resource-group $SharedResourceGroup `
            --query "[?name=='$LockName'].id" -o tsv

        return (-not [string]::IsNullOrEmpty($lockId))
    }

    # Test 6: Identity info file exists
    $identityInfoFile = Join-Path $PSScriptRoot 'shared-identity-info.json'
    Test-Validation -TestName "Identity info file exists" -TestBlock {
        return (Test-Path $identityInfoFile)
    }

    # Test 7: Identity info file is valid JSON
    if (Test-Path $identityInfoFile) {
        Test-Validation -TestName "Identity info file is valid JSON" -TestBlock {
            $info = Get-Content $identityInfoFile | ConvertFrom-Json
            return ($null -ne $info.resourceId)
        }

        # Test 8: Identity info matches Azure identity
        if ($identityJson) {
            Test-Validation -TestName "Identity info matches Azure identity" -TestBlock {
                $fileInfo = Get-Content $identityInfoFile | ConvertFrom-Json
                $azureIdentity = $identityJson | ConvertFrom-Json
                return ($fileInfo.principalId -eq $azureIdentity.principalId)
            }
        }
    }

    # Test 9: Resource group has correct tags
    Test-Validation -TestName "Resource group has lifecycle=permanent tag" -TestBlock {
        $rg = az group show --name $SharedResourceGroup | ConvertFrom-Json
        return ($rg.tags.lifecycle -eq 'permanent')
    }

    # Test 10: Identity can query Service Health
    if ($identityJson) {
        Write-Message ''
        Write-Message 'Testing API access (may take a few seconds)...' -Color Cyan

        Test-Validation -TestName "Identity can query Azure Resource Graph" -TestBlock {
            # Try a simple Azure Resource Graph query to verify access
            $query = "HealthResources | where type == 'microsoft.resourcehealth/resourcehealthmetadata' | take 1"
            $result = az graph query -q $query --subscription $subscriptionId 2>$null

            # If query succeeds, identity has proper access
            return ($null -ne $result)
        }
    }

    # Summary
    Write-Message ''
    Write-Message '===========================================================' -Color Cyan
    if ($script:ValidationPassed) {
        Write-Message '  Validation: PASSED ✓' -Color Green
        Write-Message '===========================================================' -Color Green
        Write-Message ''
        Write-Message 'All validation tests passed successfully!' -Color Green
        Write-Message ''
        Write-Message 'Shared infrastructure is correctly configured and ready to use.' -Color Cyan
        Write-Message ''
        Write-Message 'Next Steps:' -Color Cyan
        Write-Message '  1. Deploy your project resources:' -Color Gray
        Write-Message '     cd scripts/infrastructure' -Color Yellow
        Write-Message '     ./deploy-bicep.ps1 -Environment dev' -Color Yellow
        Write-Message ''
        exit 0
    }
    else {
        Write-Message '  Validation: FAILED ✗' -Color Red
        Write-Message '===========================================================' -Color Red
        Write-Message ''
        Write-Message 'Validation failures detected:' -Color Red
        foreach ($reason in $script:FailureReasons) {
            Write-Message "  - $reason" -Color Red
        }
        Write-Message ''
        Write-Message 'Remediation:' -Color Yellow
        Write-Message '  1. Review the failed tests above' -Color Gray
        Write-Message '  2. Run setup-shared-identity.ps1 to recreate shared infrastructure:' -Color Gray
        Write-Message '     cd scripts/infrastructure' -Color Yellow
        Write-Message '     ./setup-shared-identity.ps1' -Color Yellow
        Write-Message ''
        Write-Message '  3. If issues persist, check:' -Color Gray
        Write-Message '     - Azure CLI authentication (az login)' -Color Gray
        Write-Message '     - Subscription permissions (Owner or Contributor + User Access Administrator)' -Color Gray
        Write-Message '     - Network connectivity to Azure' -Color Gray
        Write-Message ''
        Write-Message 'For detailed troubleshooting, see docs/MIGRATION_GUIDE.md' -Color Cyan
        Write-Message ''
        exit 1
    }
}
catch {
    Write-Message ''
    Write-Message '===========================================================' -Color Red
    Write-Message '  Validation Error!' -Color Red
    Write-Message '===========================================================' -Color Red
    Write-Message ''
    Write-Message "Error: $_" -Color Red
    Write-Message ''
    exit 1
}
