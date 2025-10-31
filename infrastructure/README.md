# Azure Infrastructure (Bicep)

This folder contains Bicep Infrastructure as Code (IaC) templates for deploying the Azure Health Monitoring solution.

## Files

- **`main.bicep`** - Main Bicep template defining all Azure resources
- **`main.bicepparam`** - Parameter file for development environment
- **`README.md`** - This file

## Resources Deployed

The Bicep template creates:

1. **Storage Account** (Standard_LRS, TLS 1.2+)
   - Blob container for Service Health cache
   - Private blob access only

2. **Application Insights** (90-day retention)
   - Web application type
   - Connected to Function App

3. **App Service Plan** (Consumption/Dynamic Y1)
   - Serverless, pay-per-execution
   - Auto-scaling

4. **Function App** (PowerShell 7.4)
   - Configured with all required app settings
   - System-assigned managed identity
   - HTTPS only, TLS 1.2+

5. **RBAC Role Assignments**
   - Reader (subscription scope) - for Service Health queries
   - Monitoring Reader (subscription scope) - for monitoring data
   - Storage Blob Data Contributor (storage scope) - for cache access

## Deployment

### Using the deployment script (recommended):

```powershell
# Deploy to dev environment
./scripts/infrastructure/deploy-bicep.ps1

# Preview changes without deploying
./scripts/infrastructure/deploy-bicep.ps1 -WhatIf

# Deploy to production
./scripts/infrastructure/deploy-bicep.ps1 -Environment prod -ResourceGroup rg-azure-health-prod
```

### Using Azure CLI directly:

```bash
# Create resource group
az group create --name rg-azure-health-dev --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-azure-health-dev \
  --template-file infrastructure/main.bicep \
  --parameters environment=dev
```

### Using Azure Portal:

1. Navigate to Azure Portal > Create a resource > Template deployment
2. Choose "Build your own template in the editor"
3. Copy contents of `main.bicep`
4. Set parameters and deploy

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `environment` | string | dev | Environment name (dev/staging/prod) |
| `location` | string | resourceGroup().location | Azure region |
| `baseName` | string | azurehealth | Base name for resources |
| `subscriptionId` | string | subscription().subscriptionId | Subscription to monitor |
| `timerSchedule` | string | 0 */15 * * * * | CRON schedule for timer trigger |
| `cacheContainerName` | string | servicehealth-cache | Blob container name |

## Outputs

The deployment provides these outputs:

- `functionAppName` - Name of the deployed Function App
- `functionAppUrl` - HTTPS URL of the Function App
- `storageAccountName` - Name of the storage account
- `appInsightsName` - Name of Application Insights
- `functionAppPrincipalId` - Managed identity principal ID
- `resourceGroupName` - Name of the resource group

## Next Steps After Deployment

1. **Deploy function code:**
   ```bash
   cd src
   func azure functionapp publish <functionAppName>
   ```

2. **Configure authentication (optional):**
   ```bash
   az webapp auth update \
     --name <functionAppName> \
     --resource-group rg-azure-health-dev \
     --enabled true \
     --action LoginWithAzureActiveDirectory
   ```

3. **Test the deployment:**
   ```bash
   curl https://<functionAppName>.azurewebsites.net/api/GetServiceHealth
   ```

## Cleanup

To delete all resources:

```bash
az group delete --name rg-azure-health-dev --yes --no-wait
```

## Best Practices Implemented

✓ Declarative Infrastructure as Code
✓ Idempotent deployments
✓ Managed Identity (no secrets/passwords)
✓ Principle of least privilege RBAC
✓ TLS 1.2+ enforcement
✓ Private storage access
✓ Environment-based naming
✓ Comprehensive tagging
✓ Resource outputs for automation
