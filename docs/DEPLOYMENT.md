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

# Deploy from the src folder
func azure functionapp publish $FUNCTION_APP --script-root src
```

### Option 2: VS Code Azure Functions Extension

1. Install the Azure Functions extension in VS Code
2. Sign in to Azure (Ctrl+Shift+P > Azure: Sign In)
3. Right-click on your function app in the Azure Functions panel
4. Select "Deploy to Function App"
5. Choose your subscription and function app
6. When prompted for the workspace folder, choose the `src/` directory
7. Confirm deployment

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
  AZURE_FUNCTIONAPP_PACKAGE_PATH: 'src'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - name: 'Checkout GitHub Action'
      uses: actions/checkout@v3

    - name: 'Setup Node.js'
      uses: actions/setup-node@v4
      with:
        node-version: '18'

    - name: 'Install Azure Functions Core Tools'
      run: |
        npm install -g azure-functions-core-tools@4 --unsafe-perm true

    - name: 'Login to Azure'
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}

    - name: 'Deploy Azure Function'
      run: |
        func azure functionapp publish ${{ env.AZURE_FUNCTIONAPP_NAME }} --script-root ${{ env.AZURE_FUNCTIONAPP_PACKAGE_PATH }}
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
  --hostname your-custom-domain.com
```
