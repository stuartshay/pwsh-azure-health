# Deployment Guide

This guide covers deploying the Azure Health Monitoring Functions to Azure.

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated
- Function code ready for deployment

## Deployment Options

### Option 1: Azure CLI (Recommended)

#### 1. Create Azure Resources

```bash
# Variables
RESOURCE_GROUP="rg-azure-health"
LOCATION="eastus"
STORAGE_ACCOUNT="stazurehealthfunc$(date +%s)"
FUNCTION_APP="func-azure-health-$(date +%s)"
APP_INSIGHTS="ai-azure-health"

# Login
az login

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Create storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS

# Create Application Insights
az monitor app-insights component create \
  --app $APP_INSIGHTS \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --application-type web

# Get Application Insights connection string
AI_CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

# Create Function App
az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --consumption-plan-location $LOCATION \
  --runtime powershell \
  --runtime-version 7.4 \
  --functions-version 4 \
  --name $FUNCTION_APP \
  --storage-account $STORAGE_ACCOUNT \
  --app-insights $APP_INSIGHTS
```

#### 2. Configure Application Settings

```bash
# Set subscription ID
az functionapp config appsettings set \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --settings "AZURE_SUBSCRIPTION_ID=your-subscription-id"

# Set Application Insights
az functionapp config appsettings set \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --settings "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING"
```

#### 3. Enable Managed Identity

```bash
# Enable system-assigned managed identity
az functionapp identity assign \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP

# Get the principal ID
PRINCIPAL_ID=$(az functionapp identity show \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Assign Reader role to the subscription
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Reader" \
  --scope "/subscriptions/your-subscription-id"

# Assign Monitoring Reader role
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Monitoring Reader" \
  --scope "/subscriptions/your-subscription-id"
```

#### 4. Deploy Function Code

```bash
# Navigate to project directory
cd pwsh-azure-health

# Deploy
func azure functionapp publish $FUNCTION_APP
```

### Option 2: VS Code Azure Functions Extension

1. Install the Azure Functions extension in VS Code
2. Sign in to Azure (Ctrl+Shift+P > Azure: Sign In)
3. Right-click on your function app in the Azure Functions panel
4. Select "Deploy to Function App"
5. Choose your subscription and function app
6. Confirm deployment

### Option 3: GitHub Actions (CI/CD)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Azure Function

on:
  push:
    branches:
      - main

env:
  AZURE_FUNCTIONAPP_NAME: 'func-azure-health'
  AZURE_FUNCTIONAPP_PACKAGE_PATH: '.'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: 'Checkout GitHub Action'
      uses: actions/checkout@v3

    - name: 'Login to Azure'
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 'Run Azure Functions Action'
      uses: Azure/functions-action@v1
      with:
        app-name: ${{ env.AZURE_FUNCTIONAPP_NAME }}
        package: ${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}
```

## Post-Deployment Configuration

### 1. Get Function URL and Key

```bash
# Get function key
FUNCTION_KEY=$(az functionapp keys list \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --query functionKeys.default -o tsv)

# Get function URL
FUNCTION_URL="https://${FUNCTION_APP}.azurewebsites.net/api/GetServiceHealth"

echo "Function URL: $FUNCTION_URL"
echo "Function Key: $FUNCTION_KEY"
```

### 2. Test the Deployed Function

```bash
curl "$FUNCTION_URL?code=$FUNCTION_KEY&SubscriptionId=your-subscription-id"
```

### 3. Configure CORS (Optional)

```bash
az functionapp cors add \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --allowed-origins "https://yourdomain.com"
```

### 4. Configure Custom Domain (Optional)

```bash
# Add custom domain
az functionapp config hostname add \
  --webapp-name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --hostname "health.yourdomain.com"

# Bind SSL certificate
az functionapp config ssl bind \
  --certificate-thumbprint <thumbprint> \
  --ssl-type SNI \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP
```

## Monitoring and Logging

### View Live Logs

```bash
func azure functionapp logstream $FUNCTION_APP
```

### Application Insights Queries

Navigate to Application Insights in Azure Portal and run KQL queries:

```kql
// Function executions
requests
| where cloud_RoleName == "func-azure-health"
| summarize count() by name, resultCode
| order by count_ desc

// Function failures
traces
| where severityLevel >= 3
| where cloud_RoleName == "func-azure-health"
| order by timestamp desc

// Performance
requests
| where cloud_RoleName == "func-azure-health"
| summarize avg(duration), max(duration) by name
```

## Scaling Configuration

### Consumption Plan (Default)

Automatic scaling based on demand.

### Premium Plan

```bash
# Create premium plan
az functionapp plan create \
  --name plan-azure-health \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku EP1 \
  --is-linux false

# Update function app to use premium plan
az functionapp update \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --plan plan-azure-health
```

## Security Best Practices

1. **Use Managed Identity**: Avoid storing credentials in configuration
2. **Rotate Function Keys**: Regularly rotate access keys
3. **Enable HTTPS Only**: 
   ```bash
   az functionapp update \
     --name $FUNCTION_APP \
     --resource-group $RESOURCE_GROUP \
     --set httpsOnly=true
   ```
4. **Configure IP Restrictions**: Limit access to known IP ranges
5. **Use Azure Key Vault**: Store sensitive configuration

## Troubleshooting Deployment

### Issue: Deployment fails with authentication error

**Solution:**
```bash
az login
az account set --subscription "your-subscription-id"
```

### Issue: Function app doesn't start

**Solution:**
Check Application Insights logs or use:
```bash
az functionapp log deployment show \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP
```

### Issue: Module not found after deployment

**Solution:**
Verify `requirements.psd1` is included in deployment and properly formatted.

## Rollback

```bash
# List deployment slots
az functionapp deployment slot list \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP

# Swap slots
az functionapp deployment slot swap \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --slot staging
```

## Cleanup Resources

```bash
# Delete resource group and all resources
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait
```

## Next Steps

- Configure [monitoring alerts](MONITORING.md)
- Set up [CI/CD pipeline](CI_CD.md)
- Review [security hardening](SECURITY.md)
