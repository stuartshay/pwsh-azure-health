#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup shared Azure infrastructure for User-Assigned Managed Identity
.DESCRIPTION
    Creates rg-azure-health-shared resource group and User-Assigned Managed Identity
    that can be shared across multiple projects (pwsh-azure-health, ts-azure-health).

    This script is designed to be moved to a separate rg-azure-health-shared repository
    in the future for centralized management of shared resources.
.PARAMETER Location
    Azure region for shared resources
.PARAMETER SubscriptionId
    Azure subscription ID (defaults to current subscription)
.PARAMETER WhatIf
    Preview changes without creating resources
.EXAMPLE
    ./setup-shared-identity.ps1
.EXAMPLE
    ./setup-shared-identity.ps1 -Location westus2 -WhatIf
.NOTES
    This resource group should NEVER be deleted as it contains critical shared infrastructure.
    Multiple projects depend on these resources.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [string]$SubscriptionId = '',

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Shared resource configuration
$SharedResourceGroup = 'rg-azure-health-shared'
$ManagedIdentityName = 'id-azurehealth-shared'
$ProjectTag = 'azure-health-monitoring'
$LockName = 'DoNotDelete-SharedInfrastructure'

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

try {
    Write-Message ''
    Write-Message '===========================================================' -Color Cyan
    Write-Message '  Azure Health Monitoring - Shared Infrastructure Setup' -Color Cyan
    Write-Message '===========================================================' -Color Cyan
    Write-Message ''
    Write-Message '⚠️  WARNING: This creates PERMANENT shared infrastructure' -Color Yellow
    Write-Message '   Multiple projects depend on these resources!' -Color Yellow
    Write-Message ''
    Write-Message 'Configuration:' -Color Cyan
    Write-Message "  Resource Group     : $SharedResourceGroup" -Color Gray
    Write-Message "  Managed Identity   : $ManagedIdentityName" -Color Gray
    Write-Message "  Location           : $Location" -Color Gray
    Write-Message "  Project Tag        : $ProjectTag" -Color Gray
    if ($WhatIf) {
        Write-Message '  Mode               : What-If (preview only)' -Color Yellow
    }
    Write-Message ''

    # Check authentication
    Write-Message 'Checking Azure CLI authentication...' -Color Cyan
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged in to Azure. Run: az login"
        exit 1
    }

    if ([string]::IsNullOrEmpty($SubscriptionId)) {
        $SubscriptionId = $account.id
    }

    Write-Message "[OK] Authenticated as: $($account.user.name)" -Color Green
    Write-Message "  Subscription: $($account.name)" -Color Gray
    Write-Message "  Subscription ID: $SubscriptionId" -Color Gray
    Write-Message ''

    if ($WhatIf) {
        Write-Message 'WHAT-IF MODE: The following actions would be performed:' -Color Yellow
        Write-Message ''
        Write-Message "1. Create/verify resource group: $SharedResourceGroup" -Color Gray
        Write-Message "2. Create User-Assigned Managed Identity: $ManagedIdentityName" -Color Gray
        Write-Message '3. Assign RBAC roles at subscription scope:' -Color Gray
        Write-Message '   - Reader (for Service Health queries)' -Color Gray
        Write-Message '   - Monitoring Reader (for monitoring data)' -Color Gray
        Write-Message "4. Apply resource lock: $LockName (CanNotDelete)" -Color Gray
        Write-Message ''
        Write-Message 'No changes will be made. Remove -WhatIf to execute.' -Color Yellow
        exit 0
    }

    # Check if resource group exists
    Write-Message 'Checking if shared resource group exists...' -Color Cyan
    $rgExists = az group exists --name $SharedResourceGroup | ConvertFrom-Json

    if ($rgExists) {
        Write-Message "[OK] Resource group exists: $SharedResourceGroup" -Color Green

        # Show existing resources
        $existingResources = az resource list --resource-group $SharedResourceGroup --query '[].{Name:name, Type:type, Tags:tags}' | ConvertFrom-Json
        if ($existingResources.Count -gt 0) {
            Write-Message ''
            Write-Message 'Existing resources in shared resource group:' -Color Cyan
            foreach ($resource in $existingResources) {
                Write-Message "  - $($resource.Name) ($($resource.Type))" -Color Gray
            }
        }
    }
    else {
        Write-Message 'Creating shared resource group...' -Color Cyan
        az group create `
            --name $SharedResourceGroup `
            --location $Location `
            --tags `
            purpose=shared-infrastructure `
            lifecycle=permanent `
            project=$ProjectTag `
            sharedBy='pwsh-azure-health,ts-azure-health' | Out-Null

        Write-Message "[OK] Created resource group: $SharedResourceGroup" -Color Green
    }
    Write-Message ''

    # Check if managed identity exists
    Write-Message 'Checking if User-Assigned Managed Identity exists...' -Color Cyan
    $identityExists = az identity show `
        --name $ManagedIdentityName `
        --resource-group $SharedResourceGroup `
        2>$null

    if ($identityExists) {
        $identity = $identityExists | ConvertFrom-Json
        Write-Message "[OK] Managed Identity already exists" -Color Green
        Write-Message "  Name        : $($identity.name)" -Color Gray
        Write-Message "  Principal ID: $($identity.principalId)" -Color Gray
        Write-Message "  Client ID   : $($identity.clientId)" -Color Gray
        Write-Message "  Resource ID : $($identity.id)" -Color Gray
    }
    else {
        Write-Message 'Creating User-Assigned Managed Identity...' -Color Cyan
        $identityJson = az identity create `
            --name $ManagedIdentityName `
            --resource-group $SharedResourceGroup `
            --location $Location `
            --tags `
            purpose=shared-identity `
            lifecycle=permanent `
            project=$ProjectTag `
            usedBy='pwsh-azure-health,ts-azure-health'

        $identity = $identityJson | ConvertFrom-Json
        Write-Message "[OK] Created Managed Identity: $ManagedIdentityName" -Color Green
        Write-Message "  Principal ID: $($identity.principalId)" -Color Gray
        Write-Message "  Client ID   : $($identity.clientId)" -Color Gray
        Write-Message "  Resource ID : $($identity.id)" -Color Gray

        # Wait for identity propagation
        Write-Message ''
        Write-Message 'Waiting for identity propagation (30 seconds)...' -Color Cyan
        Start-Sleep -Seconds 30
    }
    Write-Message ''

    # Assign Reader role at subscription scope
    Write-Message 'Assigning RBAC roles at subscription scope...' -Color Cyan
    Write-Message '  Role: Reader (for Service Health queries)' -Color Gray

    $readerRoleExists = az role assignment list `
        --assignee $identity.principalId `
        --role Reader `
        --scope "/subscriptions/$SubscriptionId" `
        --query '[0].id' -o tsv

    if ($readerRoleExists) {
        Write-Message '  [SKIP] Reader role already assigned' -Color Yellow
    }
    else {
        az role assignment create `
            --assignee $identity.principalId `
            --role Reader `
            --scope "/subscriptions/$SubscriptionId" | Out-Null
        Write-Message '  [OK] Reader role assigned' -Color Green
    }

    # Assign Monitoring Reader role at subscription scope
    Write-Message '  Role: Monitoring Reader (for monitoring data)' -Color Gray

    $monitoringRoleExists = az role assignment list `
        --assignee $identity.principalId `
        --role 'Monitoring Reader' `
        --scope "/subscriptions/$SubscriptionId" `
        --query '[0].id' -o tsv

    if ($monitoringRoleExists) {
        Write-Message '  [SKIP] Monitoring Reader role already assigned' -Color Yellow
    }
    else {
        az role assignment create `
            --assignee $identity.principalId `
            --role 'Monitoring Reader' `
            --scope "/subscriptions/$SubscriptionId" | Out-Null
        Write-Message '  [OK] Monitoring Reader role assigned' -Color Green
    }
    Write-Message ''

    # Apply resource lock to prevent accidental deletion
    Write-Message 'Applying resource lock to prevent accidental deletion...' -Color Cyan
    $lockExists = az lock list `
        --resource-group $SharedResourceGroup `
        --query "[?name=='$LockName'].id" -o tsv

    if ($lockExists) {
        Write-Message "  [SKIP] Lock already exists: $LockName" -Color Yellow
    }
    else {
        az lock create `
            --name $LockName `
            --resource-group $SharedResourceGroup `
            --lock-type CanNotDelete `
            --notes "Prevents accidental deletion of shared infrastructure used by multiple projects" | Out-Null
        Write-Message "  [OK] Applied lock: $LockName" -Color Green
    }
    Write-Message ''

    # Save identity information to file for reference
    $outputFile = Join-Path $PSScriptRoot 'shared-identity-info.json'
    $identityInfo = @{
        resourceGroup  = $SharedResourceGroup
        identityName   = $ManagedIdentityName
        principalId    = $identity.principalId
        clientId       = $identity.clientId
        resourceId     = $identity.id
        location       = $Location
        subscriptionId = $SubscriptionId
        createdDate    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    $identityInfo | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding utf8
    Write-Message "Identity information saved to: $outputFile" -Color Cyan
    Write-Message ''

    # Display summary
    Write-Message '===========================================================' -Color Green
    Write-Message '  Setup Complete!' -Color Green
    Write-Message '===========================================================' -Color Green
    Write-Message ''
    Write-Message 'Shared Infrastructure Summary:' -Color Cyan
    Write-Message "  Resource Group      : $SharedResourceGroup" -Color Gray
    Write-Message "  Managed Identity    : $ManagedIdentityName" -Color Gray
    Write-Message "  Principal ID        : $($identity.principalId)" -Color Gray
    Write-Message "  Client ID           : $($identity.clientId)" -Color Gray
    Write-Message "  Resource ID         : $($identity.id)" -Color Gray
    Write-Message "  Resource Lock       : $LockName (CanNotDelete)" -Color Gray
    Write-Message ''
    Write-Message 'RBAC Assignments:' -Color Cyan
    Write-Message '  ✓ Reader (subscription scope)' -Color Gray
    Write-Message '  ✓ Monitoring Reader (subscription scope)' -Color Gray
    Write-Message ''
    Write-Message 'Next Steps:' -Color Cyan
    Write-Message '  1. Use this Managed Identity in your project deployments' -Color Gray
    Write-Message "     Identity Resource ID: $($identity.id)" -Color Yellow
    Write-Message ''
    Write-Message '  2. For pwsh-azure-health deployment:' -Color Gray
    Write-Message '     Update infrastructure/main.bicepparam with:' -Color Gray
    Write-Message "     param managedIdentityResourceId = '$($identity.id)'" -Color Yellow
    Write-Message ''
    Write-Message '  3. For storage access, assign Storage Blob Data Contributor:' -Color Gray
    Write-Message '     az role assignment create \' -Color Yellow
    Write-Message "       --assignee $($identity.principalId) \\" -Color Yellow
    Write-Message '       --role "Storage Blob Data Contributor" \' -Color Yellow
    Write-Message '       --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{storage}' -Color Yellow
    Write-Message ''
    Write-Message '⚠️  IMPORTANT: This resource group should NEVER be deleted!' -Color Yellow
    Write-Message '   Multiple projects depend on this infrastructure.' -Color Yellow
    Write-Message ''

}
catch {
    Write-Message ''
    Write-Message '===========================================================' -Color Red
    Write-Message '  Setup Failed!' -Color Red
    Write-Message '===========================================================' -Color Red
    Write-Message ''
    Write-Message "Error: $_" -Color Red
    Write-Message ''
    exit 1
}
