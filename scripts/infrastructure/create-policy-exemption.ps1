#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a policy exemption for Azure Health Monitoring Function App deployment
.DESCRIPTION
    Creates an exemption for the "Require Microsoft Entra ID Authentication for Function Apps" policy
    to allow deployment of the Function App during development.
.PARAMETER ResourceGroup
    Name of the resource group to exempt
.PARAMETER ExemptionName
    Name for the policy exemption
.EXAMPLE
    ./create-policy-exemption.ps1 -ResourceGroup rg-azure-health-dev
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup = 'rg-azure-health-dev',

    [Parameter()]
    [string]$ExemptionName = 'azure-health-function-auth-exemption'
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information to emit user-friendly status lines without Write-Host usage.
.PARAMETER Message
    Text to display.
.PARAMETER Color
    Optional color name applied when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet('Default', 'Cyan', 'Gray', 'Green', 'Yellow')]
        [string]$Color = 'Default'
    )

    $prefix = ''
    $suffix = ''

    if ($PSStyle) {
        switch ($Color) {
            'Cyan'   { $prefix = $PSStyle.Foreground.Cyan }
            'Gray'   { $prefix = $PSStyle.Foreground.Gray }
            'Green'  { $prefix = $PSStyle.Foreground.Green }
            'Yellow' { $prefix = $PSStyle.Foreground.Yellow }
        }

        if ($prefix) {
            $suffix = $PSStyle.Reset
        }
    }

    Write-Information ("{0}{1}{2}" -f $prefix, $Message, $suffix)
}

Write-Message ''
Write-Message '===========================================================' -Color Cyan
Write-Message '  Azure Policy Exemption Creation' -Color Cyan
Write-Message '===========================================================' -Color Cyan
Write-Message ''

# Find the policy assignment
Write-Message 'Searching for Function App authentication policy...' -Color Cyan
$policyAssignments = az policy assignment list --query "[?contains(displayName, 'Function') && contains(displayName, 'Entra')]" | ConvertFrom-Json

if ($policyAssignments.Count -eq 0) {
    Write-Message '[WARN] No Function App authentication policy found' -Color Yellow
    Write-Message "Listing all policies with 'Function' in the name:" -Color Gray
    az policy assignment list --query "[?contains(displayName, 'Function')].{Name:displayName, Id:id}" --output table
    exit 1
}

$policyAssignment = $policyAssignments[0]
Write-Message "Found policy: $($policyAssignment.displayName)" -Color Green
Write-Message "  Assignment ID: $($policyAssignment.id)" -Color Gray
Write-Message ''

# Get resource group ID
Write-Message 'Getting resource group information...' -Color Cyan
$rg = az group show --name $ResourceGroup | ConvertFrom-Json
$rgId = $rg.id
Write-Message "[OK] Resource Group: $($rg.name)" -Color Green
Write-Message "  ID: $rgId" -Color Gray
Write-Message ''

# Create exemption
Write-Message 'Creating policy exemption...' -Color Cyan
Write-Message "  Exemption Name: $ExemptionName" -Color Gray
Write-Message '  Scope: Resource Group' -Color Gray
Write-Message '  Category: Waiver' -Color Gray
Write-Message ''

try {
    $exemption = az policy exemption create `
        --name $ExemptionName `
        --display-name "Azure Health Monitoring - Development Function App" `
        --policy-assignment $policyAssignment.id `
        --exemption-category Waiver `
        --scope $rgId `
        --description "Temporary exemption for Azure Health Monitoring Function App development. Authentication will be configured post-deployment." `
        --output json | ConvertFrom-Json

    Write-Message '===========================================================' -Color Green
    Write-Message '  [OK] Policy Exemption Created Successfully!' -Color Green
    Write-Message '===========================================================' -Color Green
    Write-Message ''
    Write-Message 'Exemption Details:' -Color Cyan
    Write-Message "  Name       : $($exemption.name)" -Color Gray
    Write-Message "  ID         : $($exemption.id)" -Color Gray
    Write-Message "  Category   : $($exemption.exemptionCategory)" -Color Gray
    Write-Message '  Expires    : Never (unless manually deleted)' -Color Gray
    Write-Message ''
    Write-Message 'Next Steps:' -Color Cyan
    Write-Message '  1. Deploy infrastructure:' -Color Gray
    Write-Message '     ./scripts/infrastructure/deploy-bicep.ps1' -Color Yellow
    Write-Message ''
    Write-Message '  2. After deployment, configure authentication manually or remove exemption:' -Color Gray
    Write-Message "     az policy exemption delete --name $ExemptionName --scope $rgId" -Color Yellow
    Write-Message ''
}
catch {
    Write-Error "Failed to create policy exemption: $_"
    Write-Message ''
    Write-Message 'Troubleshooting:' -Color Yellow
    Write-Message '  - Verify you have Owner or Policy Contributor role' -Color Gray
    Write-Message '  - Check if exemption already exists:' -Color Gray
    Write-Message "    az policy exemption list --scope $rgId" -Color Yellow
    Write-Message ''
    exit 1
}
