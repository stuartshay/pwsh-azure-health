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
$InformationPreference = 'Continue'

<#
.SYNOPSIS
    Writes an informational message with optional ANSI coloring.
.DESCRIPTION
    Wraps Write-Information so deployment scripts can emit status messages without Write-Host.
.PARAMETER Message
    Text to display.
.PARAMETER Color
    Optional color name applied when ANSI styling is available.
#>
function Write-Message {
    param(
        [Parameter(Mandatory)]
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

# Navigate to infrastructure directory (go up two levels from scripts/infrastructure)
$infraDir = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath '..','infrastructure'
Push-Location $infraDir

try {
    Write-Message ''
    Write-Message '===========================================================' -Color Cyan
    Write-Message '  Azure Health Monitoring - Bicep Deployment' -Color Cyan
    Write-Message '===========================================================' -Color Cyan
    Write-Message ''
    Write-Message 'Configuration:' -Color Cyan
    Write-Message "  Resource Group : $ResourceGroup" -Color Gray
    Write-Message "  Location       : $Location" -Color Gray
    Write-Message "  Environment    : $Environment" -Color Gray
    Write-Message '  Template       : main.bicep' -Color Gray
    if ($WhatIf) {
        Write-Message '  Mode           : What-If (preview only)' -Color Yellow
    }
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

    # Create resource group
    Write-Message 'Creating resource group...' -Color Cyan
    $rgExists = az group exists --name $ResourceGroup | ConvertFrom-Json

    if ($rgExists) {
        Write-Message "[OK] Resource group exists: $ResourceGroup" -Color Green
    }
    else {
        az group create `
            --name $ResourceGroup `
            --location $Location `
            --tags environment=$Environment purpose=monitoring | Out-Null
        Write-Message "[OK] Created resource group: $ResourceGroup" -Color Green
    }
    Write-Message ''

    # Deploy Bicep template
    if ($WhatIf) {
        Write-Message 'Running What-If analysis...' -Color Cyan
        az deployment group what-if `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment
    }
    else {
        Write-Message 'Deploying Bicep template...' -Color Cyan
        Write-Message '(This may take 3-5 minutes)' -Color Gray
        Write-Message ''

        $deployment = az deployment group create `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment `
            --output json | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            Write-Message ''
            Write-Message '===========================================================' -Color Green
            Write-Message '  Deployment Successful!' -Color Green
            Write-Message '===========================================================' -Color Green
            Write-Message ''
            Write-Message 'Deployed Resources:' -Color Cyan
            Write-Message "  Resource Group      : $($deployment.properties.outputs.resourceGroupName.value)" -Color Gray
            Write-Message "  Function App        : $($deployment.properties.outputs.functionAppName.value)" -Color Gray
            Write-Message "  Function URL        : $($deployment.properties.outputs.functionAppUrl.value)" -Color Gray
            Write-Message "  Storage Account     : $($deployment.properties.outputs.storageAccountName.value)" -Color Gray
            Write-Message "  App Insights        : $($deployment.properties.outputs.appInsightsName.value)" -Color Gray
            Write-Message "  Managed Identity ID : $($deployment.properties.outputs.functionAppPrincipalId.value)" -Color Gray
            Write-Message ''
            Write-Message 'Next Steps:' -Color Cyan
            Write-Message '  1. Deploy function code:' -Color Gray
            Write-Message "     cd src && func azure functionapp publish $($deployment.properties.outputs.functionAppName.value)" -Color Yellow
            Write-Message ''
            Write-Message '  2. Test the deployment:' -Color Gray
            Write-Message "     curl $($deployment.properties.outputs.functionAppUrl.value)/api/GetServiceHealth" -Color Yellow
            Write-Message ''
            Write-Message '  3. View logs:' -Color Gray
            Write-Message "     az functionapp log tail --name $($deployment.properties.outputs.functionAppName.value) --resource-group $ResourceGroup" -Color Yellow
            Write-Message ''
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
