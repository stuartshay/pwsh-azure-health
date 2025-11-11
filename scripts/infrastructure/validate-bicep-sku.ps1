#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates Bicep template with both Y1 and EP1 SKUs
.DESCRIPTION
    Tests deployment validation for both Consumption (Y1) and Elastic Premium (EP1) plans.
    Compares configuration differences and validates both SKUs can deploy successfully.
.PARAMETER ResourceGroup
    Name of the resource group for validation (will be created if not exists)
.PARAMETER Location
    Azure region for validation
.PARAMETER Environment
    Environment: dev, staging, or prod
.EXAMPLE
    ./validate-bicep-sku.ps1
.EXAMPLE
    ./validate-bicep-sku.ps1 -Environment dev -Location eastus
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup = 'rg-azure-health-validation',

    [Parameter()]
    [string]$Location = 'eastus',

    [Parameter()]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'

# Helper function for colored output
function Write-Message {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

# Change to infrastructure directory
Push-Location "$PSScriptRoot/../../infrastructure"

try {
    Write-Message "`n╔══════════════════════════════════════════════════════════════╗" -Color Cyan
    Write-Message "║  Bicep SKU Validation: Y1 (Consumption) vs EP1 (Premium)    ║" -Color Cyan
    Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Cyan

    # Check Azure CLI
    Write-Message "Checking Azure CLI..." -Color Gray
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        Write-Error "Azure CLI is not installed or not in PATH. Please install: https://aka.ms/installazurecli"
    }
    Write-Message "[OK] Azure CLI version: $($azVersion.'azure-cli')" -Color Green
    Write-Message ''

    # Check if logged in
    Write-Message "Checking Azure authentication..." -Color Gray
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        Write-Error "Not logged into Azure. Run: az login"
    }
    Write-Message "[OK] Logged in as: $($account.user.name)" -Color Green
    Write-Message "[OK] Subscription: $($account.name)" -Color Green
    Write-Message ''

    # Check for shared infrastructure
    Write-Message "Checking shared infrastructure..." -Color Gray
    $sharedIdentityFile = "$PSScriptRoot/shared-identity-info.json"
    if (-not (Test-Path $sharedIdentityFile)) {
        Write-Error "Shared identity file not found: $sharedIdentityFile`nRun: ./scripts/infrastructure/setup-shared-identity.ps1"
    }

    $sharedInfo = Get-Content $sharedIdentityFile | ConvertFrom-Json
    $managedIdentityResourceId = $sharedInfo.resourceId

    if (-not $managedIdentityResourceId) {
        Write-Error "Could not read managed identity resource ID from $sharedIdentityFile"
    }
    Write-Message "[OK] Managed Identity: $managedIdentityResourceId" -Color Green
    Write-Message ''

    # Create validation resource group if it doesn't exist
    Write-Message "Checking validation resource group..." -Color Gray
    $rgExists = az group exists --name $ResourceGroup --output tsv
    if ($rgExists -eq 'false') {
        Write-Message "Creating validation resource group: $ResourceGroup" -Color Yellow
        az group create `
            --name $ResourceGroup `
            --location $Location `
            --tags purpose=validation environment=test | Out-Null
        Write-Message "[OK] Created resource group" -Color Green
    } else {
        Write-Message "[OK] Resource group exists: $ResourceGroup" -Color Green
    }
    Write-Message ''

    # Validation results
    $results = @{
        Y1 = @{ Success = $false; Duration = 0; Output = '' }
        EP1 = @{ Success = $false; Duration = 0; Output = '' }
    }

    # Validate Y1 (Consumption)
    Write-Message "╔══════════════════════════════════════════════════════════════╗" -Color Blue
    Write-Message "║  Validating Y1 (Consumption Plan)                           ║" -Color Blue
    Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Blue

    $y1StartTime = Get-Date
    try {
        $y1Output = az deployment group validate `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment `
            --parameters functionAppPlanSku=Y1 `
            --parameters managedIdentityResourceId=$managedIdentityResourceId `
            --output json 2>&1

        $y1EndTime = Get-Date
        $results.Y1.Duration = ($y1EndTime - $y1StartTime).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
            $results.Y1.Success = $true
            $results.Y1.Output = $y1Output | ConvertFrom-Json
            Write-Message "✅ Y1 validation PASSED" -Color Green
            Write-Message "   Duration: $([math]::Round($results.Y1.Duration, 2))s" -Color Gray
        } else {
            $results.Y1.Output = $y1Output
            Write-Message "❌ Y1 validation FAILED" -Color Red
            Write-Message "   Duration: $([math]::Round($results.Y1.Duration, 2))s" -Color Gray
            Write-Message "   Error: $y1Output" -Color Red
        }
    } catch {
        $y1EndTime = Get-Date
        $results.Y1.Duration = ($y1EndTime - $y1StartTime).TotalSeconds
        $results.Y1.Output = $_.Exception.Message
        Write-Message "❌ Y1 validation FAILED" -Color Red
        Write-Message "   Exception: $($_.Exception.Message)" -Color Red
    }
    Write-Message ''

    # Validate EP1 (Premium)
    Write-Message "╔══════════════════════════════════════════════════════════════╗" -Color Magenta
    Write-Message "║  Validating EP1 (Elastic Premium Plan)                      ║" -Color Magenta
    Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Magenta

    $ep1StartTime = Get-Date
    try {
        $ep1Output = az deployment group validate `
            --resource-group $ResourceGroup `
            --template-file main.bicep `
            --parameters environment=$Environment `
            --parameters functionAppPlanSku=EP1 `
            --parameters managedIdentityResourceId=$managedIdentityResourceId `
            --output json 2>&1

        $ep1EndTime = Get-Date
        $results.EP1.Duration = ($ep1EndTime - $ep1StartTime).TotalSeconds

        if ($LASTEXITCODE -eq 0) {
            $results.EP1.Success = $true
            $results.EP1.Output = $ep1Output | ConvertFrom-Json
            Write-Message "✅ EP1 validation PASSED" -Color Green
            Write-Message "   Duration: $([math]::Round($results.EP1.Duration, 2))s" -Color Gray
        } else {
            $results.EP1.Output = $ep1Output
            Write-Message "❌ EP1 validation FAILED" -Color Red
            Write-Message "   Duration: $([math]::Round($results.EP1.Duration, 2))s" -Color Gray
            Write-Message "   Error: $ep1Output" -Color Red
        }
    } catch {
        $ep1EndTime = Get-Date
        $results.EP1.Duration = ($ep1EndTime - $ep1StartTime).TotalSeconds
        $results.EP1.Output = $_.Exception.Message
        Write-Message "❌ EP1 validation FAILED" -Color Red
        Write-Message "   Exception: $($_.Exception.Message)" -Color Red
    }
    Write-Message ''

    # Display comparison summary
    Write-Message "╔══════════════════════════════════════════════════════════════╗" -Color Cyan
    Write-Message "║  Validation Summary                                          ║" -Color Cyan
    Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Cyan

    $table = @"
┌──────────────┬──────────────┬──────────────┬──────────────────────────┐
│ SKU          │ Status       │ Duration     │ Features                 │
├──────────────┼──────────────┼──────────────┼──────────────────────────┤
│ Y1           │ $(if ($results.Y1.Success) { "✅ PASSED   " } else { "❌ FAILED   " }) │ $("{0,8:F2}s" -f $results.Y1.Duration) │ Pay-per-execution        │
│ (Consumption)│              │              │ Scales to zero           │
│              │              │              │ Cold starts              │
├──────────────┼──────────────┼──────────────┼──────────────────────────┤
│ EP1          │ $(if ($results.EP1.Success) { "✅ PASSED   " } else { "❌ FAILED   " }) │ $("{0,8:F2}s" -f $results.EP1.Duration) │ Always warm (alwaysOn)   │
│ (Premium)    │              │              │ VNet integration ready   │
│              │              │              │ Health check support     │
│              │              │              │ Pre-warmed instances     │
└──────────────┴──────────────┴──────────────┴──────────────────────────┘
"@

    Write-Host $table

    Write-Message ''
    Write-Message "Configuration Differences:" -Color Cyan
    Write-Message "  • alwaysOn:              Y1=false  │  EP1=true" -Color Gray
    Write-Message "  • preWarmedInstanceCount:    Y1=null   │  EP1=1" -Color Gray
    Write-Message "  • healthCheckPath:           Y1=null   │  EP1=/api/HealthCheck" -Color Gray
    Write-Message "  • Estimated Cost/Month:      Y1=~\$0-20 │  EP1=~\$146" -Color Gray
    Write-Message ''

    # Overall result
    $overallSuccess = $results.Y1.Success -and $results.EP1.Success

    if ($overallSuccess) {
        Write-Message "╔══════════════════════════════════════════════════════════════╗" -Color Green
        Write-Message "║  ✅ SUCCESS: Both SKUs validated successfully                ║" -Color Green
        Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Green
        Write-Message "Your Bicep template supports both Y1 and EP1 deployments." -Color Green
        Write-Message ''
        exit 0
    } else {
        Write-Message "╔══════════════════════════════════════════════════════════════╗" -Color Red
        Write-Message "║  ❌ FAILURE: One or more validations failed                  ║" -Color Red
        Write-Message "╚══════════════════════════════════════════════════════════════╝`n" -Color Red

        if (-not $results.Y1.Success) {
            Write-Message "Y1 (Consumption) validation failed. Check the error above." -Color Red
        }
        if (-not $results.EP1.Success) {
            Write-Message "EP1 (Premium) validation failed. Check the error above." -Color Red
        }
        Write-Message ''
        exit 1
    }
}
catch {
    Write-Error "Validation failed: $_"
    exit 1
}
finally {
    Pop-Location
}
