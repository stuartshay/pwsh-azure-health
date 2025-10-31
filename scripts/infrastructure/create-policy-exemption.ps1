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

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Azure Policy Exemption Creation" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Find the policy assignment
Write-Host "Searching for Function App authentication policy..." -ForegroundColor Cyan
$policyAssignments = az policy assignment list --query "[?contains(displayName, 'Function') && contains(displayName, 'Entra')]" | ConvertFrom-Json

if ($policyAssignments.Count -eq 0) {
    Write-Host "⚠️  No Function App authentication policy found" -ForegroundColor Yellow
    Write-Host "Listing all policies with 'Function' in the name:" -ForegroundColor Gray
    az policy assignment list --query "[?contains(displayName, 'Function')].{Name:displayName, Id:id}" --output table
    exit 1
}

$policyAssignment = $policyAssignments[0]
Write-Host "✓ Found policy: $($policyAssignment.displayName)" -ForegroundColor Green
Write-Host "  Assignment ID: $($policyAssignment.id)" -ForegroundColor Gray
Write-Host ""

# Get resource group ID
Write-Host "Getting resource group information..." -ForegroundColor Cyan
$rg = az group show --name $ResourceGroup | ConvertFrom-Json
$rgId = $rg.id
Write-Host "✓ Resource Group: $($rg.name)" -ForegroundColor Green
Write-Host "  ID: $rgId" -ForegroundColor Gray
Write-Host ""

# Create exemption
Write-Host "Creating policy exemption..." -ForegroundColor Cyan
Write-Host "  Exemption Name: $ExemptionName" -ForegroundColor Gray
Write-Host "  Scope: Resource Group" -ForegroundColor Gray
Write-Host "  Category: Waiver" -ForegroundColor Gray
Write-Host ""

try {
    $exemption = az policy exemption create `
        --name $ExemptionName `
        --display-name "Azure Health Monitoring - Development Function App" `
        --policy-assignment $policyAssignment.id `
        --exemption-category Waiver `
        --scope $rgId `
        --description "Temporary exemption for Azure Health Monitoring Function App development. Authentication will be configured post-deployment." `
        --output json | ConvertFrom-Json
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  ✓ Policy Exemption Created Successfully!" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Exemption Details:" -ForegroundColor Cyan
    Write-Host "  Name       : $($exemption.name)" -ForegroundColor Gray
    Write-Host "  ID         : $($exemption.id)" -ForegroundColor Gray
    Write-Host "  Category   : $($exemption.exemptionCategory)" -ForegroundColor Gray
    Write-Host "  Expires    : Never (unless manually deleted)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Deploy infrastructure:" -ForegroundColor Gray
    Write-Host "     ./scripts/infrastructure/deploy-bicep.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. After deployment, configure authentication manually or remove exemption:" -ForegroundColor Gray
    Write-Host "     az policy exemption delete --name $ExemptionName --scope $rgId" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Error "Failed to create policy exemption: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Verify you have Owner or Policy Contributor role" -ForegroundColor Gray
    Write-Host "  - Check if exemption already exists:" -ForegroundColor Gray
    Write-Host "    az policy exemption list --scope $rgId" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
