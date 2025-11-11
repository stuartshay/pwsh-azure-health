# Azure Cost Estimation & Analysis

This document describes the cost estimation and analysis features integrated into the infrastructure deployment workflow.

## Overview

The deployment workflow now includes automated cost estimation before deployment and actual cost analysis after deployment, providing visibility into Azure spending.

## Tools Used

### 1. ACE (Azure Cost Estimator)

**Purpose:** Pre-deployment cost estimation from Bicep/ARM templates

- **Repository:** [TheCloudTheory/arm-estimator](https://github.com/TheCloudTheory/arm-estimator)
- **Version:** 1.6.4
- **Website:** https://azure-cost-estimator.thecloudtheory.com/
- **Description:** Automated cost estimations for ARM Templates, Bicep, and Terraform

**How it works:**
1. Transpiles Bicep templates to ARM JSON
2. Analyzes resource configurations
3. Estimates monthly costs based on Azure pricing
4. Provides detailed cost breakdowns by resource type

### 2. azure-cost-cli

**Purpose:** Post-deployment actual cost analysis

- **Repository:** [mivano/azure-cost-cli](https://github.com/mivano/azure-cost-cli)
- **Version:** 0.52.0
- **Description:** CLI tool to perform cost analysis on your Azure subscription

**How it works:**
1. Queries Azure Cost Management API
2. Retrieves actual spending data
3. Provides cost breakdowns by resource group
4. Supports various time frames (day, week, month)

## Workflow Integration

### Pre-Deployment Cost Estimation

**Step:** `Estimate deployment costs (Pre-Deploy)`

```yaml
- Transpiles Bicep to ARM template
- Runs ACE with deployment parameters
- Extracts estimated monthly cost
- Adds cost estimate to GitHub step summary
```

**Output includes:**
- Estimated monthly cost
- Detailed cost breakdown (expandable)
- SKU and environment information

### Post-Deployment Cost Analysis

**Step:** `Analyze actual deployment costs (Post-Deploy)`

```yaml
- Queries Azure Cost Management API
- Retrieves month-to-date costs for resource group
- Compares with pre-deployment estimate
- Adds actual costs to GitHub step summary
```

**Output includes:**
- Actual month-to-date cost
- Cost status (available or pending)
- Detailed cost breakdown (if available)
- Follow-up instructions for delayed data

### Cost Comparison Summary

**Step:** `Generate cost comparison summary`

Creates a comprehensive cost report with:

```yaml
- Pre-deployment estimate
- Post-deployment actual costs
- Environment and SKU details
- Deployment information
- Useful links to Azure Portal
- Follow-up actions
```

## Understanding Cost Data

### Estimated Costs (Pre-Deploy)

**When available:** Immediately before deployment

**Accuracy:**
- Based on Azure retail pricing
- Assumes standard usage patterns
- Does not account for:
  - Reserved instances
  - Spot pricing
  - Enterprise agreements
  - Consumption variations

**Use cases:**
- Budget planning
- Cost comparisons between SKUs
- Architecture decision-making

### Actual Costs (Post-Deploy)

**When available:** 8-24 hours after resource creation

**Accuracy:**
- Based on actual Azure billing data
- Includes all charges and discounts
- Reflects real usage patterns

**Limitations:**
- Newly deployed resources take time to appear in Cost Management
- Shows month-to-date costs (not projected monthly)
- May include costs from other resources in the resource group

## Cost Report Summary

The workflow generates a comprehensive **Azure Cost Report Summary** in the GitHub Actions step summary:

### Example Output

```markdown
# 💰 Azure Cost Report Summary

## Cost Overview

| Metric | Value |
|--------|-------|
| **Pre-Deployment Estimate** | `$15.50` |
| **Post-Deployment Actual** | `Not yet available` |
| **Environment** | `dev` |
| **SKU** | `Y1` |
| **Resource Group** | `rg-azure-health-dev` |

## ⏳ Cost Comparison

Actual cost data is not yet available. Azure Cost Management typically
requires 8-24 hours to process new resource costs.

### Follow-up Actions

1. **Check costs in 24 hours**
2. **Set up cost alerts** in Azure Portal
3. **Review Azure Advisor** recommendations

## 📋 Deployment Details

- **Function App:** `func-azurehealth-dev-xyz`
- **Storage Account:** `stazurehealthdev123`
- **App Insights:** `ai-azurehealth-dev`
- **Deployment Time:** 2025-11-11 15:30:00 UTC

## 🔗 Useful Links

- Azure Cost Management
- Resource Group Portal Link
- Azure Advisor
```

## Manual Cost Analysis

### Using azure-cost-cli locally

```bash
# Install azure-cost-cli
wget https://github.com/mivano/azure-cost-cli/releases/download/0.52.0/azure-cost-cli-linux-x64.tar.gz
tar -xzf azure-cost-cli-linux-x64.tar.gz

# Authenticate with Azure
az login

# Get costs for resource group
./azure-cost-cli \
  --subscription <subscription-id> \
  --resource-group rg-azure-health-dev \
  --output json \
  --timeframe MonthToDate
```

### Using Azure CLI

```bash
# Query cost management for resource group
az costmanagement query \
  --type ActualCost \
  --dataset-filter '{"and":[{"dimensions":{"name":"ResourceGroup","operator":"In","values":["rg-azure-health-dev"]}}]}' \
  --timeframe MonthToDate
```

### Using Azure Portal

1. Navigate to **Cost Management + Billing**
2. Select your subscription
3. Click **Cost analysis**
4. Filter by resource group: `rg-azure-health-dev`

## Cost Optimization Tips

### Function App (Consumption Plan - Y1)

**Current cost:** ~$0.20/month (first 1M executions free)

**Optimization:**
- Monitor execution count vs. limit
- Consider Premium plan (EP1) only if:
  - Need VNet integration
  - Require always-on functionality
  - Experience cold start issues

### Storage Account (Standard_LRS)

**Current cost:** ~$0.18/GB/month + transactions

**Optimization:**
- Enable lifecycle management
- Move old blobs to Cool/Archive tiers
- Delete unused containers

### Application Insights (90-day retention)

**Current cost:** First 5GB/month free, then $2.30/GB

**Optimization:**
- Adjust data retention period
- Use sampling for high-traffic apps
- Configure adaptive sampling

## Setting Up Cost Alerts

### Using Azure Portal

1. Go to **Cost Management + Billing** → **Cost alerts**
2. Click **+ Add**
3. Select alert type:
   - **Budget:** Set monthly spending limit
   - **Anomaly:** Detect unusual spending patterns
4. Configure:
   - Alert threshold (e.g., 80% of budget)
   - Email recipients
   - Action groups (optional)

### Using Azure CLI

```bash
# Create a budget with alert
az consumption budget create \
  --budget-name "azure-health-dev-budget" \
  --category Cost \
  --amount 50 \
  --time-grain Monthly \
  --start-date 2025-11-01 \
  --end-date 2026-11-01 \
  --resource-group rg-azure-health-dev
```

## Troubleshooting

### ACE returns "Unable to calculate"

**Possible causes:**
- Invalid Bicep template
- Missing required parameters
- Unsupported resource types

**Solution:**
- Check ACE output in workflow logs
- Verify Bicep template builds successfully
- Ensure all parameters are provided

### azure-cost-cli returns "Not yet available"

**Possible causes:**
- Resources just deployed (< 24 hours)
- Cost data not yet processed
- No charges incurred yet (within free tier)

**Solution:**
- Wait 24 hours and re-check
- Use Azure Portal for immediate visibility
- Verify resources are running

### Cost estimate much higher than actual

**Possible causes:**
- Estimate assumes full month usage
- Actual costs are month-to-date only
- Free tier benefits applied to actual costs
- Resources not running full time

**Solution:**
- Compare estimated monthly vs. prorated actual
- Check Azure pricing calculator
- Review free tier benefits

## References

- [ACE Documentation](https://github.com/TheCloudTheory/arm-estimator)
- [azure-cost-cli Documentation](https://github.com/mivano/azure-cost-cli)
- [Azure Cost Management Documentation](https://learn.microsoft.com/azure/cost-management-billing/)
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Azure Pricing](https://azure.microsoft.com/pricing/)

## Next Steps

1. **Monitor costs regularly** using Azure Portal
2. **Set up budget alerts** to avoid surprises
3. **Review Azure Advisor** recommendations monthly
4. **Optimize resources** based on actual usage patterns
5. **Consider Reserved Instances** for predictable workloads
