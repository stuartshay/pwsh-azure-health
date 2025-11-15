# Azure Cost Estimation Guide

## Overview

This project uses a dual-approach cost estimation system:
1. **Primary Estimator**: PowerShell script with JSON-based pricing data (`estimate-costs.ps1`)
2. **Secondary Estimator**: ACE (Azure Cost Estimator) for comparison

## Files

- `infrastructure/cost-config.json` - Pricing database
- `scripts/infrastructure/estimate-costs.ps1` - Cost estimation script
- `.github/workflows/infrastructure-deploy.yml` - Automated cost estimation in CI/CD

## Maintenance

### Updating Pricing Data

The `cost-config.json` file contains Azure pricing that may change over time. Follow these steps to keep it current:

#### Method 1: Azure Pricing API (Recommended)

```bash
# Get current pricing for Function App Plans
az rest --method get --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Azure Functions' and armRegionName eq 'eastus' and priceType eq 'Consumption'"

# Get storage pricing
az rest --method get --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Storage' and armRegionName eq 'eastus'"

# Get Application Insights pricing
az rest --method get --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Azure Monitor' and armRegionName eq 'eastus'"
```

#### Method 2: Azure Pricing Calculator

1. Visit [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
2. Configure:
   - Function App Premium EP1 plan
   - Storage Account (Standard LRS)
   - Application Insights
3. Note the monthly costs
4. Update `infrastructure/cost-config.json`

#### Method 3: Azure Portal

1. Navigate to Azure Portal → Create Resource
2. Select the resource type
3. View pricing during configuration
4. Update `cost-config.json` with current values

### Recommended Update Schedule

- **Quarterly**: Review and update all pricing
- **After Azure announcements**: Update when Microsoft announces price changes
- **Before major deployments**: Verify pricing is current

### Version Header

Update the version metadata in `cost-config.json`:

```json
{
  "lastUpdated": "2025-11-15",
  "version": "1.0.0"
}
```

## Adding New Resources

When you add new resources to your Bicep template, follow these steps:

### Step 1: Update cost-config.json

Add the new resource pricing under the appropriate region:

```json
{
  "regions": {
    "eastus": {
      "newResourceType": {
        "skuName": {
          "name": "Resource Display Name",
          "baseCost": 0.0,
          "description": "Resource description",
          "notes": "Additional notes"
        }
      }
    }
  }
}
```

### Step 2: Update estimate-costs.ps1

Add a helper function for the new resource:

```powershell
function Get-NewResourceCost {
    param(
        [object]$RegionPricing,
        [string]$SkuName = "Standard"
    )

    $resourcePricing = $RegionPricing.newResourceType.$SkuName

    if (-not $resourcePricing) {
        return @{
            Name = $SkuName
            TotalCost = 0.0
            Notes = "Pricing data not available"
        }
    }

    return @{
        Name = $resourcePricing.name
        TotalCost = $resourcePricing.baseCost
        Notes = $resourcePricing.notes
    }
}
```

### Step 3: Update the main calculation logic

```powershell
# In the Main Logic section, add:
$newResource = Get-NewResourceCost -RegionPricing $regionPricing
$newResourceCost = $newResource.TotalCost

# Update total cost calculation:
$totalCost = $functionAppCost + $storageCost + $appInsightsCost + $newResourceCost

# Add to result object:
$result.Costs.NewResource = @{
    Name = $newResource.Name
    MonthlyCost = $newResourceCost
    Notes = $newResource.Notes
}
```

### Step 4: Update output formatting

Add the new resource to the text output:

```powershell
Write-ColorOutput "4. New Resource Type" -Color White
Write-ColorOutput "   Monthly Cost: $(Format-Currency $newResourceCost)" -Color Green
if ($newResource.Notes) {
    Write-ColorOutput "   Notes: $($newResource.Notes)" -Color Gray
}
Write-Host ""
```

## Examples

### Adding Azure Key Vault

**1. Update cost-config.json:**

```json
{
  "regions": {
    "eastus": {
      "keyVault": {
        "Standard": {
          "name": "Azure Key Vault",
          "baseCost": 0.03,
          "unit": "per 10,000 operations",
          "estimatedOperations": 10000,
          "notes": "First 250,000 operations free, then $0.03 per 10k operations"
        }
      }
    }
  }
}
```

### Adding Azure SQL Database

**1. Update cost-config.json:**

```json
{
  "regions": {
    "eastus": {
      "sqlDatabase": {
        "Basic": {
          "name": "Azure SQL Database Basic",
          "baseCost": 4.99,
          "vCores": 1,
          "storage": "2 GB",
          "notes": "Basic tier - 5 DTUs"
        },
        "S0": {
          "name": "Azure SQL Database Standard S0",
          "baseCost": 14.98,
          "vCores": 1,
          "storage": "250 GB",
          "notes": "Standard tier - 10 DTUs"
        }
      }
    }
  }
}
```

## Detecting Outdated Pricing

The system has several mechanisms to detect outdated pricing:

### 1. Cost Validation

The script includes validation that will fail if costs are unrealistic:

```powershell
# EP1 should be >= $100
if ($Sku -eq 'EP1' -and $totalCost -lt 100) {
    # Validation fails - pricing may be outdated
}
```

### 2. Dual Estimation Comparison

The GitHub Actions workflow compares PowerShell and ACE estimates:

```bash
# If difference > 10%, a warning is shown
if (( $(echo "$ABS_DIFF > 10" | bc -l) )); then
  echo "⚠️  Significant difference detected between estimators"
fi
```

### 3. Version Tracking

Check the `lastUpdated` field in `cost-config.json`:

```bash
# Alert if pricing is older than 6 months
LAST_UPDATED=$(jq -r '.lastUpdated' infrastructure/cost-config.json)
# Compare with current date
```

## Fallback Behavior

If pricing data is missing or unavailable:

1. **Script falls back to defaults**:
   ```powershell
   if (-not $storagePricing) {
       return @{
           Name = $StorageSku
           BaseCost = 0.02
           TotalCost = 0.02
       }
   }
   ```

2. **Warning is displayed**:
   ```
   ⚠️ Warning: No pricing data for region 'westeurope'. Using 'eastus' as fallback.
   ```

3. **ACE provides secondary estimate**:
   - Even if PowerShell pricing is outdated, ACE runs independently
   - Comparison helps identify discrepancies

## Best Practices

1. **Keep cost-config.json in version control**: Track pricing changes over time
2. **Document pricing sources**: Add URLs to `sources` array in config
3. **Test after updates**: Run `estimate-costs.ps1 -Validate` after changing pricing
4. **Review quarterly**: Set calendar reminders to review pricing
5. **Use automation**: Consider creating a script to fetch pricing from Azure API
6. **Monitor actual costs**: Compare estimates with actual Azure billing

## Automation Ideas

### Automated Pricing Updates

Create a scheduled job to update pricing:

```powershell
# scripts/infrastructure/update-pricing.ps1
param([string]$Region = "eastus")

# Fetch current EP1 pricing
$ep1Price = az rest --method get --url "https://prices.azure.com/api/retail/prices?..." | ConvertFrom-Json

# Update cost-config.json
$config = Get-Content infrastructure/cost-config.json | ConvertFrom-Json
$config.regions.$Region.functionAppPlans.EP1.baseCost = $ep1Price.price
$config.lastUpdated = Get-Date -Format "yyyy-MM-dd"
$config | ConvertTo-Json -Depth 10 | Set-Content infrastructure/cost-config.json
```

### Pricing Alert System

Add a GitHub Action to check pricing age:

```yaml
- name: Check pricing freshness
  run: |
    LAST_UPDATED=$(jq -r '.lastUpdated' infrastructure/cost-config.json)
    AGE_DAYS=$(( ($(date +%s) - $(date -d "$LAST_UPDATED" +%s)) / 86400 ))
    if [ $AGE_DAYS -gt 180 ]; then
      echo "⚠️  Pricing data is $AGE_DAYS days old. Consider updating."
      echo "Visit docs/COST_ESTIMATION.md for update instructions."
    fi
```

## Troubleshooting

### Issue: Costs seem too low

**Solution**:
1. Check `lastUpdated` in `cost-config.json`
2. Verify pricing at [Azure Pricing](https://azure.microsoft.com/en-us/pricing/)
3. Run estimation with `-Validate` flag to trigger checks

### Issue: New resource not estimated

**Solution**:
1. Ensure resource is added to `cost-config.json`
2. Create cost calculation function in script
3. Add resource to total cost calculation
4. Add resource to output formatting

### Issue: Regional pricing differences

**Solution**:
1. Add region-specific pricing to `cost-config.json`
2. Script automatically falls back to `eastus` if region not found
3. Update script logic if needed for region-specific calculations

## References

- [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
- [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
- [Azure Functions Pricing](https://azure.microsoft.com/en-us/pricing/details/functions/)
- [Azure Storage Pricing](https://azure.microsoft.com/en-us/pricing/details/storage/blobs/)
- [Application Insights Pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/)

## Support

For questions or issues:
1. Check this documentation
2. Review `scripts/infrastructure/estimate-costs.ps1` comments
3. Run script with `-Verbose` for detailed output
4. Compare with ACE output in GitHub Actions logs
