#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Grants managed identities access to the shared Key Vault
.DESCRIPTION
    Configures RBAC permissions for the shared Key Vault (kv-tsazurehealth) to allow:
    - Shared managed identity (id-azurehealth-shared) to read secrets
    - GitHub Actions service principal to write secrets
    - Frontend app identities to read secrets
.PARAMETER GrantGitHubActions
    Grant GitHub Actions service principal Key Vault Secrets Officer role
.PARAMETER GitHubActionsAppId
    Application ID of the GitHub Actions service principal (required if -GrantGitHubActions)
.EXAMPLE
    ./setup-keyvault-access.ps1
.EXAMPLE
    ./setup-keyvault-access.ps1 -GrantGitHubActions -GitHubActionsAppId "12345678-1234-1234-1234-123456789012"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$GrantGitHubActions,

    [Parameter()]
    [string]$GitHubActionsAppId = ''
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Configuration
$SharedResourceGroup = 'rg-azure-health-shared'
$KeyVaultName = 'kv-tsazurehealth'
$SharedIdentityName = 'id-azurehealth-shared'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring
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

try {
    Write-Message ''
    Write-Message '===========================================================' -Color Cyan
    Write-Message '  Key Vault Access Configuration' -Color Cyan
    Write-Message '===========================================================' -Color Cyan
    Write-Message ''
    Write-Message "Key Vault: $KeyVaultName" -Color Gray
    Write-Message "Resource Group: $SharedResourceGroup" -Color Gray
    Write-Message ''

    # Check authentication
    Write-Message 'Checking Azure CLI authentication...' -Color Cyan
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged in to Azure. Run: az login"
        exit 1
    }

    $subscriptionId = $account.id
    Write-Message "[OK] Authenticated as: $($account.user.name)" -Color Green
    Write-Message "  Subscription: $($account.name)" -Color Gray
    Write-Message ''

    # Verify Key Vault exists
    Write-Message 'Verifying Key Vault exists...' -Color Cyan
    $keyVault = az keyvault show `
        --name $KeyVaultName `
        --resource-group $SharedResourceGroup `
        2>$null | ConvertFrom-Json

    if (-not $keyVault) {
        Write-Error "Key Vault '$KeyVaultName' not found in resource group '$SharedResourceGroup'"
        exit 1
    }

    Write-Message "[OK] Key Vault found: $KeyVaultName" -Color Green
    Write-Message "  Location: $($keyVault.location)" -Color Gray
    Write-Message "  RBAC Enabled: $($keyVault.properties.enableRbacAuthorization)" -Color Gray
    Write-Message ''

    $kvScope = "/subscriptions/$subscriptionId/resourceGroups/$SharedResourceGroup/providers/Microsoft.KeyVault/vaults/$KeyVaultName"

    # Grant access to shared managed identity
    Write-Message 'Configuring shared managed identity access...' -Color Cyan
    $sharedIdentity = az identity show `
        --name $SharedIdentityName `
        --resource-group $SharedResourceGroup `
        2>$null | ConvertFrom-Json

    if (-not $sharedIdentity) {
        Write-Message "[WARN] Shared identity '$SharedIdentityName' not found - skipping" -Color Yellow
    }
    else {
        Write-Message "  Identity: $SharedIdentityName" -Color Gray
        Write-Message "  Principal ID: $($sharedIdentity.principalId)" -Color Gray

        # Check if role already exists
        $existingRole = az role assignment list `
            --assignee $sharedIdentity.principalId `
            --role 'Key Vault Secrets User' `
            --scope $kvScope `
            --query '[0].id' -o tsv 2>$null

        if ($existingRole) {
            Write-Message '  [SKIP] Key Vault Secrets User role already assigned' -Color Yellow
        }
        else {
            Write-Message '  Granting Key Vault Secrets User role...' -Color Cyan
            az role assignment create `
                --assignee $sharedIdentity.principalId `
                --role 'Key Vault Secrets User' `
                --scope $kvScope `
                --output none

            Write-Message '  [OK] Key Vault Secrets User role granted' -Color Green
        }
    }
    Write-Message ''

    # Grant access to frontend app identities
    Write-Message 'Configuring frontend app identity access...' -Color Cyan
    foreach ($env in @('dev', 'prod')) {
        $tsIdentityName = "id-tsazurehealth-$env"
        $tsResourceGroup = "rg-azure-health-$env"

        $tsIdentity = az identity show `
            --name $tsIdentityName `
            --resource-group $tsResourceGroup `
            2>$null | ConvertFrom-Json

        if (-not $tsIdentity) {
            Write-Message "  [SKIP] Frontend identity '$tsIdentityName' not found" -Color Yellow
            continue
        }

        Write-Message "  Identity: $tsIdentityName" -Color Gray
        Write-Message "  Principal ID: $($tsIdentity.principalId)" -Color Gray

        # Check if role already exists
        $existingRole = az role assignment list `
            --assignee $tsIdentity.principalId `
            --role 'Key Vault Secrets User' `
            --scope $kvScope `
            --query '[0].id' -o tsv 2>$null

        if ($existingRole) {
            Write-Message '    [SKIP] Key Vault Secrets User role already assigned' -Color Yellow
        }
        else {
            Write-Message '    Granting Key Vault Secrets User role...' -Color Cyan
            az role assignment create `
                --assignee $tsIdentity.principalId `
                --role 'Key Vault Secrets User' `
                --scope $kvScope `
                --output none

            Write-Message '    [OK] Key Vault Secrets User role granted' -Color Green
        }
        Write-Message ''
    }

    # Grant access to GitHub Actions service principal
    if ($GrantGitHubActions) {
        Write-Message 'Configuring GitHub Actions service principal access...' -Color Cyan

        if ([string]::IsNullOrEmpty($GitHubActionsAppId)) {
            Write-Error "GitHub Actions App ID is required. Use: -GitHubActionsAppId '<app-id>'"
            exit 1
        }

        Write-Message "  App ID: $GitHubActionsAppId" -Color Gray

        # Check if role already exists
        $existingRole = az role assignment list `
            --assignee $GitHubActionsAppId `
            --role 'Key Vault Secrets Officer' `
            --scope $kvScope `
            --query '[0].id' -o tsv 2>$null

        if ($existingRole) {
            Write-Message '  [SKIP] Key Vault Secrets Officer role already assigned' -Color Yellow
        }
        else {
            Write-Message '  Granting Key Vault Secrets Officer role...' -Color Cyan
            az role assignment create `
                --assignee $GitHubActionsAppId `
                --role 'Key Vault Secrets Officer' `
                --scope $kvScope `
                --output none

            Write-Message '  [OK] Key Vault Secrets Officer role granted' -Color Green
        }
        Write-Message ''
    }
    else {
        Write-Message 'GitHub Actions access not configured (use -GrantGitHubActions)' -Color Gray
        Write-Message ''
    }

    # Display current role assignments
    Write-Message 'Current Key Vault role assignments:' -Color Cyan
    $roleAssignments = az role assignment list `
        --scope $kvScope `
        --query "[].{Principal:principalName, Role:roleDefinitionName, Type:principalType}" `
        --output table

    Write-Output $roleAssignments
    Write-Message ''

    # Display summary
    Write-Message '===========================================================' -Color Green
    Write-Message '  Key Vault Access Configuration Complete!' -Color Green
    Write-Message '===========================================================' -Color Green
    Write-Message ''
    Write-Message 'Summary:' -Color Cyan
    Write-Message "  ✅ Shared identity ($SharedIdentityName) can read secrets" -Color Gray
    Write-Message '  ✅ Frontend identities can read secrets' -Color Gray
    if ($GrantGitHubActions) {
        Write-Message '  ✅ GitHub Actions can write secrets' -Color Gray
    }
    Write-Message ''
    Write-Message 'Usage in Function App code:' -Color Cyan
    Write-Message '  $secretValue = az keyvault secret show \' -Color Gray
    Write-Message "    --vault-name $KeyVaultName \\" -Color Gray
    Write-Message '    --name <secret-name> \' -Color Gray
    Write-Message '    --query value -o tsv' -Color Gray
    Write-Message ''
    Write-Message 'Next steps:' -Color Cyan
    Write-Message '  1. Deploy infrastructure - workflow will update Key Vault secret' -Color Gray
    Write-Message '  2. Frontend app can read function-app-url-{env} secret' -Color Gray
    Write-Message '  3. Backend app can read shared configuration secrets' -Color Gray
    Write-Message ''

}
catch {
    Write-Error "Failed to configure Key Vault access: $_"
    exit 1
}
