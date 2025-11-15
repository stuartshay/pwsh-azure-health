#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Estimate Azure deployment costs based on Bicep configuration.

.DESCRIPTION
    This script provides accurate cost estimation for Azure Function App deployments
    by reading pricing data from cost-config.json and calculating costs for:
    - Function App Plan (Consumption Y1 or Elastic Premium EP1/EP2/EP3)
    - Storage Account (Standard LRS)
    - Application Insights (with data ingestion estimates)

    The script is designed to replace or supplement ACE (Azure Cost Estimator)
    which may not accurately estimate EP1 and other premium SKU costs.

.PARAMETER BicepFile
    Path to the main Bicep template file

.PARAMETER ParametersFile
    Path to the Bicep parameters file

.PARAMETER Environment
    Environment name (dev, staging, prod) - overrides parameters file

.PARAMETER Sku
    Function App Plan SKU (Y1, EP1, EP2, EP3) - overrides parameters file

.PARAMETER Region
    Azure region for deployment (e.g., eastus, westus) - overrides parameters file

.PARAMETER CostConfigFile
    Path to the cost configuration JSON file (default: infrastructure/cost-config.json)

.PARAMETER OutputFormat
    Output format: 'text' (human-readable), 'json', or 'both' (default)

.PARAMETER Validate
    Enable validation mode: fails if EP1 cost < $100 or Y1 cost > $50

.EXAMPLE
    ./estimate-costs.ps1 -Environment dev -Sku EP1 -Region eastus

.EXAMPLE
    ./estimate-costs.ps1 -BicepFile infrastructure/main.bicep -ParametersFile infrastructure/main.bicepparam -Validate

.EXAMPLE
    ./estimate-costs.ps1 -Sku EP1 -Region eastus -OutputFormat json

.NOTES
    Author: Azure Health Monitoring Team
    Version: 1.0.0
    Last Updated: 2025-11-15
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BicepFile = "infrastructure/main.bicep",

    [Parameter(Mandatory = $false)]
    [string]$ParametersFile = "infrastructure/main.bicepparam",

    [Parameter(Mandatory = $false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Y1', 'EP1', 'EP2', 'EP3')]
    [string]$Sku,

    [Parameter(Mandatory = $false)]
    [string]$Region,

    [Parameter(Mandatory = $false)]
    [string]$CostConfigFile = "infrastructure/cost-config.json",

    [Parameter(Mandatory = $false)]
    [ValidateSet('text', 'json', 'both')]
    [string]$OutputFormat = 'both',

    [Parameter(Mandatory = $false)]
    [switch]$Validate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    if ($OutputFormat -eq 'json') {
        return # Don't output colored text in JSON mode
    }

    Write-Host $Message -ForegroundColor $Color
}

function Get-BicepParameter {
    param(
        [string]$ParametersFilePath,
        [string]$ParameterName
    )

    if (-not (Test-Path $ParametersFilePath)) {
        return $null
    }

    $content = Get-Content $ParametersFilePath -Raw

    # Parse simple param assignments (e.g., param environment = 'dev')
    if ($content -match "param\s+$ParameterName\s*=\s*'([^']+)'") {
        return $Matches[1]
    }

    return $null
}

function Get-CostConfiguration {
    param(
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Cost configuration file not found: $ConfigPath"
    }

    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $config
    }
    catch {
        throw "Failed to parse cost configuration file: $_"
    }
}

function Get-RegionPricing {
    param(
        [object]$CostConfig,
        [string]$RegionName
    )

    $regionPricing = $CostConfig.regions.$RegionName

    if (-not $regionPricing) {
        Write-ColorOutput "Warning: No pricing data for region '$RegionName'. Using 'eastus' as fallback." -Color Yellow
        $regionPricing = $CostConfig.regions.eastus
    }

    return $regionPricing
}

function Get-FunctionAppPlanCost {
    param(
        [object]$RegionPricing,
        [string]$SkuName
    )

    $planPricing = $RegionPricing.functionAppPlans.$SkuName

    if (-not $planPricing) {
        # Fallback to base region if not found
        Write-ColorOutput "Warning: No pricing data for SKU '$SkuName' in this region. Using default." -Color Yellow
        return @{
            Name = $SkuName
            BaseCost = 0.0
            Notes = "Pricing data not available"
        }
    }

    return $planPricing
}

function Get-StorageCost {
    param(
        [object]$RegionPricing,
        [string]$StorageSku = "Standard_LRS",
        [double]$EstimatedGB = 1.0
    )

    $storagePricing = $RegionPricing.storage.$StorageSku

    if (-not $storagePricing) {
        return @{
            Name = $StorageSku
            BaseCost = 0.02
            TotalCost = 0.02
        }
    }

    # Use provided estimated usage or default
    if ($storagePricing.estimatedUsage) {
        $EstimatedGB = $storagePricing.estimatedUsage.functionApp
    }

    $totalCost = $storagePricing.baseCost * $EstimatedGB

    return @{
        Name = $storagePricing.name
        BaseCost = $storagePricing.baseCost
        EstimatedGB = $EstimatedGB
        TotalCost = [Math]::Round($totalCost, 2)
        Unit = $storagePricing.unit
    }
}

function Get-AppInsightsCost {
    param(
        [object]$RegionPricing,
        [double]$EstimatedGB = 0.5
    )

    $appInsightsPricing = $RegionPricing.applicationInsights.basic

    if (-not $appInsightsPricing) {
        return @{
            Name = "Application Insights"
            TotalCost = 0.0
            EstimatedGB = $EstimatedGB
            Notes = "Likely within free tier"
        }
    }

    # Use standard estimated usage if not provided
    if ($appInsightsPricing.estimatedUsage -and $EstimatedGB -le 0) {
        $EstimatedGB = $appInsightsPricing.estimatedUsage.standard
    }

    $freeGB = $appInsightsPricing.dataIngestion.free
    $costPerGB = $appInsightsPricing.dataIngestion.costPerGB

    $billableGB = [Math]::Max(0, $EstimatedGB - $freeGB)
    $totalCost = [Math]::Round($billableGB * $costPerGB, 2)

    return @{
        Name = $appInsightsPricing.name
        EstimatedGB = $EstimatedGB
        FreeGB = $freeGB
        BillableGB = $billableGB
        CostPerGB = $costPerGB
        TotalCost = $totalCost
        Notes = if ($totalCost -eq 0) { "Within free tier (first $freeGB GB/month)" } else { "Exceeds free tier" }
    }
}

function Format-Currency {
    param(
        [double]$Amount
    )

    return "`${0:N2}" -f $Amount
}

#endregion

#region Main Logic

try {
    Write-ColorOutput "`n╔══════════════════════════════════════════════════════════════════════════════╗" -Color Cyan
    Write-ColorOutput "║            Azure Cost Estimator - PowerShell Edition v1.0.0                  ║" -Color Cyan
    Write-ColorOutput "╚══════════════════════════════════════════════════════════════════════════════╝`n" -Color Cyan

    # Load cost configuration
    Write-ColorOutput "📂 Loading cost configuration from: $CostConfigFile" -Color White
    $costConfig = Get-CostConfiguration -ConfigPath $CostConfigFile
    Write-ColorOutput "✅ Cost configuration loaded (version: $($costConfig.version), updated: $($costConfig.lastUpdated))`n" -Color Green

    # Determine parameters (command-line overrides file defaults)
    if (-not $Environment) {
        $Environment = Get-BicepParameter -ParametersFilePath $ParametersFile -ParameterName 'environment'
        if (-not $Environment) { $Environment = 'dev' }
    }

    if (-not $Sku) {
        $Sku = Get-BicepParameter -ParametersFilePath $ParametersFile -ParameterName 'functionAppPlanSku'
        if (-not $Sku) { $Sku = 'Y1' }
    }

    if (-not $Region) {
        $Region = Get-BicepParameter -ParametersFilePath $ParametersFile -ParameterName 'location'
        if (-not $Region) { $Region = 'eastus' }
    }

    Write-ColorOutput "📋 Estimation Parameters:" -Color White
    Write-ColorOutput "   Environment: $Environment" -Color Gray
    Write-ColorOutput "   SKU: $Sku" -Color Gray
    Write-ColorOutput "   Region: $Region`n" -Color Gray

    # Get regional pricing
    $regionPricing = Get-RegionPricing -CostConfig $costConfig -RegionName $Region

    # Calculate individual costs
    Write-ColorOutput "💰 Calculating costs...`n" -Color White

    # Function App Plan
    $functionAppPlan = Get-FunctionAppPlanCost -RegionPricing $regionPricing -SkuName $Sku
    $functionAppCost = $functionAppPlan.baseCost

    # Storage Account
    $storage = Get-StorageCost -RegionPricing $regionPricing
    $storageCost = $storage.TotalCost

    # Application Insights
    $appInsights = Get-AppInsightsCost -RegionPricing $regionPricing
    $appInsightsCost = $appInsights.TotalCost

    # Total
    $totalCost = $functionAppCost + $storageCost + $appInsightsCost

    # Build result object
    $functionAppPlanResult = @{
        Name = $functionAppPlan.name
        Sku = $Sku
        MonthlyCost = $functionAppCost
    }

    # Add optional properties if they exist
    if ($functionAppPlan.PSObject.Properties['tier']) { $functionAppPlanResult.Tier = $functionAppPlan.tier }
    if ($functionAppPlan.PSObject.Properties['description']) { $functionAppPlanResult.Description = $functionAppPlan.description }
    if ($functionAppPlan.PSObject.Properties['notes']) { $functionAppPlanResult.Notes = $functionAppPlan.notes }

    $result = @{
        Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ'
        Configuration = @{
            Environment = $Environment
            Sku = $Sku
            Region = $Region
            BicepFile = $BicepFile
            ParametersFile = $ParametersFile
        }
        Costs = @{
            FunctionAppPlan = $functionAppPlanResult
            Storage = @{
                Name = $storage.Name
                Sku = "Standard_LRS"
                EstimatedGB = $storage.EstimatedGB
                MonthlyCost = $storageCost
            }
            ApplicationInsights = @{
                Name = $appInsights.Name
                EstimatedGB = $appInsights.EstimatedGB
                FreeGB = $appInsights.FreeGB
                BillableGB = $appInsights.BillableGB
                MonthlyCost = $appInsightsCost
                Notes = $appInsights.Notes
            }
            Total = @{
                MonthlyCost = [Math]::Round($totalCost, 2)
                Currency = "USD"
                BillingPeriod = "Monthly"
            }
        }
        Validation = @{
            Enabled = $Validate.IsPresent
            Results = @()
        }
    }

    # Validation checks
    if ($Validate) {
        Write-ColorOutput "🔍 Running validation checks...`n" -Color White

        $validationPassed = $true

        # Check 1: EP1 should be >= $100
        if ($Sku -eq 'EP1' -and $totalCost -lt 100) {
            $validationMessage = "FAIL: EP1 plan cost ($totalCost) is less than expected minimum (`$100)"
            Write-ColorOutput "   ❌ $validationMessage" -Color Red
            $result.Validation.Results += @{
                Check = "EP1 Minimum Cost"
                Status = "FAIL"
                Expected = ">= `$100"
                Actual = $totalCost
                Message = $validationMessage
            }
            $validationPassed = $false
        }
        elseif ($Sku -eq 'EP1') {
            $validationMessage = "PASS: EP1 plan cost ($totalCost) meets expected minimum"
            Write-ColorOutput "   ✅ $validationMessage" -Color Green
            $result.Validation.Results += @{
                Check = "EP1 Minimum Cost"
                Status = "PASS"
                Expected = ">= `$100"
                Actual = $totalCost
                Message = $validationMessage
            }
        }

        # Check 2: Y1 base cost should be near $0
        if ($Sku -eq 'Y1' -and $functionAppCost -gt 1) {
            $validationMessage = "FAIL: Y1 (Consumption) plan should have near-zero base cost, got `$$functionAppCost"
            Write-ColorOutput "   ❌ $validationMessage" -Color Red
            $result.Validation.Results += @{
                Check = "Y1 Base Cost"
                Status = "FAIL"
                Expected = "~$0 (pay-per-use)"
                Actual = $functionAppCost
                Message = $validationMessage
            }
            $validationPassed = $false
        }
        elseif ($Sku -eq 'Y1') {
            $validationMessage = "PASS: Y1 (Consumption) plan has expected pay-per-use pricing"
            Write-ColorOutput "   ✅ $validationMessage" -Color Green
            $result.Validation.Results += @{
                Check = "Y1 Base Cost"
                Status = "PASS"
                Expected = "~`$0 (pay-per-use)"
                Actual = $functionAppCost
                Message = $validationMessage
            }
        }

        $result.Validation.Passed = $validationPassed

        if (-not $validationPassed) {
            Write-ColorOutput "`n❌ Validation failed! Cost estimates do not meet expected ranges.`n" -Color Red
            if ($OutputFormat -ne 'json') {
                exit 1
            }
        }
        else {
            Write-ColorOutput "`n✅ All validation checks passed!`n" -Color Green
        }
    }

    # Output results
    if ($OutputFormat -eq 'text' -or $OutputFormat -eq 'both') {
        Write-ColorOutput "┌──────────────────────────────────────────────────────────────────────────────┐" -Color Cyan
        Write-ColorOutput "│ Cost Breakdown                                                                │" -Color Cyan
        Write-ColorOutput "└──────────────────────────────────────────────────────────────────────────────┘`n" -Color Cyan

        Write-ColorOutput "1. Function App Plan ($Sku - $($functionAppPlan.name))" -Color White
        Write-ColorOutput "   Monthly Cost: $(Format-Currency $functionAppCost)" -Color Green
        if ($functionAppPlan.PSObject.Properties['description']) {
            Write-ColorOutput "   Details: $($functionAppPlan.description)" -Color Gray
        }
        if ($functionAppPlan.PSObject.Properties['notes']) {
            Write-ColorOutput "   Notes: $($functionAppPlan.notes)" -Color Gray
        }
        Write-Host ""

        Write-ColorOutput "2. Storage Account (Standard LRS)" -Color White
        Write-ColorOutput "   Monthly Cost: $(Format-Currency $storageCost)" -Color Green
        Write-ColorOutput "   Estimated: $($storage.EstimatedGB) GB storage" -Color Gray
        Write-Host ""

        Write-ColorOutput "3. Application Insights" -Color White
        Write-ColorOutput "   Monthly Cost: $(Format-Currency $appInsightsCost)" -Color Green
        Write-ColorOutput "   Estimated: $($appInsights.EstimatedGB) GB data ingestion" -Color Gray
        Write-ColorOutput "   $($appInsights.Notes)" -Color Gray
        Write-Host ""

        Write-ColorOutput "┌──────────────────────────────────────────────────────────────────────────────┐" -Color Cyan
        Write-ColorOutput "│ Total Estimated Monthly Cost                                                  │" -Color Cyan
        Write-ColorOutput "└──────────────────────────────────────────────────────────────────────────────┘`n" -Color Cyan

        Write-ColorOutput "   $(Format-Currency $totalCost) USD/month`n" -Color Green

        if ($Sku -eq 'Y1') {
            Write-ColorOutput "   ℹ️  Note: Consumption (Y1) plan has additional variable costs based on:" -Color Yellow
            Write-ColorOutput "      - Function executions (first 1M free, then `$0.20 per million)" -Color Yellow
            Write-ColorOutput "      - GB-seconds of execution (first 400,000 GB-s free)" -Color Yellow
            Write-ColorOutput "      The estimate above includes only storage and App Insights base costs.`n" -Color Yellow
        }
    }

    if ($OutputFormat -eq 'json' -or $OutputFormat -eq 'both') {
        if ($OutputFormat -eq 'both') {
            Write-ColorOutput "`n📄 JSON Output:" -Color White
        }

        $jsonOutput = $result | ConvertTo-Json -Depth 10
        Write-Output $jsonOutput
    }

    Write-ColorOutput "✅ Cost estimation completed successfully!`n" -Color Green

    exit 0
}
catch {
    Write-Error "❌ Error during cost estimation: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}

#endregion
