#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Azure infrastructure using Bicep template
.DESCRIPTION
    Creates resource group and deploys all resources using Azure Bicep IaC.
    More reliable than imperative scripts - declarative and idempotent.
.PARAMETER ResourceGroup
    Name of the resource group to create/use
.PARAMETER Location
    Azure region for deployment
.PARAMETER Environment
    Environment: dev, staging, or prod
.PARAMETER WhatIf
    Preview changes without deploying
.EXAMPLE
    ./deploy-bicep.ps1
.EXAMPLE
    ./deploy-bicep.ps1 -Environment prod -Location westus2 -WhatIf
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup = 'rg-azure-health-dev',

    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',

    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Navigate to infrastructure directory (go up two levels from scripts/infrastructure)
$infraDir = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..','infrastructure'
Push-Location $infraDir

try {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Azure Health Monitoring - Bicep Deployment" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Resource Group : $ResourceGroup" -ForegroundColor Gray
    Write-Host "  Location       : $Location" -ForegroundColor Gray
    Write-Host "  Environment    : $Environment" -ForegroundColor Gray
    Write-Host "  Template       : main.bicep" -ForegroundColor Gray
    if ($WhatIf) {
        Write-Host "  Mode           : What-If (preview only)" -ForegroundColor Yellow
    }
    Write-Host ""

    # Check authentication
    Write-Host "Checking Azure CLI authentication..." -ForegroundColor Cyan
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged in to Azure. Run: az login"
        exit 1
    }
    Write-Host "✓ Authenticated as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
    Write-Host ""

    # Create resource group
    Write-Host "Creating resource group..." -ForegroundColor Cyan
    $rgExists = az group exists --name $ResourceGroup | ConvertFrom-Json

    if ($rgExists) {
        Write-Host "✓ Resource group exists: $ResourceGroup" -ForegroundColor Green
    }
    else {
        az group create `
            --name $ResourceGroup `
            --location $Location `
            --tags environment=$Environment purpose=monitoring | Out-Null
        Write-Host "✓ Created resource group: $ResourceGroup" -ForegroundColor Green
    }
    Write-Host ""

    # Deploy Bicep template
    if ($WhatIf) {
        Write-Host "Running What-If analysis..." -ForegroundColor Cyan
        az deployment group what-if `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment
    }
    else {
        Write-Host "Deploying Bicep template..." -ForegroundColor Cyan
        Write-Host "(This may take 3-5 minutes)" -ForegroundColor Gray
        Write-Host ""

        $deployment = az deployment group create `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment `
            --output json | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host "  Deployment Successful!" -ForegroundColor Green
            Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
            Write-Host ""
            Write-Host "Deployed Resources:" -ForegroundColor Cyan
            Write-Host "  Resource Group      : $($deployment.properties.outputs.resourceGroupName.value)" -ForegroundColor Gray
            Write-Host "  Function App        : $($deployment.properties.outputs.functionAppName.value)" -ForegroundColor Gray
            Write-Host "  Function URL        : $($deployment.properties.outputs.functionAppUrl.value)" -ForegroundColor Gray
            Write-Host "  Storage Account     : $($deployment.properties.outputs.storageAccountName.value)" -ForegroundColor Gray
            Write-Host "  App Insights        : $($deployment.properties.outputs.appInsightsName.value)" -ForegroundColor Gray
            Write-Host "  Managed Identity ID : $($deployment.properties.outputs.functionAppPrincipalId.value)" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Next Steps:" -ForegroundColor Cyan
            Write-Host "  1. Deploy function code:" -ForegroundColor Gray
            Write-Host "     cd src && func azure functionapp publish $($deployment.properties.outputs.functionAppName.value)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  2. Test the deployment:" -ForegroundColor Gray
            Write-Host "     curl $($deployment.properties.outputs.functionAppUrl.value)/api/GetServiceHealth" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  3. View logs:" -ForegroundColor Gray
            Write-Host "     az functionapp log tail --name $($deployment.properties.outputs.functionAppName.value) --resource-group $ResourceGroup" -ForegroundColor Yellow
            Write-Host ""
        }
        else {
            Write-Error "Deployment failed. Check the output above for details."
            exit 1
        }
    }
}
catch {
    Write-Error "Deployment failed: $_"
    exit 1
}
finally {
    Pop-Location
}
