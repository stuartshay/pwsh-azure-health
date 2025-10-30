# Deployment Guide

This guide covers deploying the Azure Health Monitoring Functions to Azure.

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated
- Function code ready for deployment

## Required Application Settings

Configure these settings before the first deployment. Values marked *(example)* can be adjusted to match your environment.

| Setting | Description |
| --- | --- |
| `AZURE_SUBSCRIPTION_ID` | Subscription that will be queried for Service Health. |
| `TIMER_CRON` | Timer trigger schedule, e.g. `0 */15 * * * *` (15 minute polling). |
| `CACHE_CONTAINER` | Blob container name for cached payloads, e.g. `servicehealth-cache`. |
| `WEBSITE_RUN_FROM_PACKAGE` | Set to `1` for package deployments. |
| EasyAuth (App Service Authentication) | Enable AAD authentication with `Unauthenticated requests: HTTP 401`. |

> 💡 The HTTP function is now read-only and serves the cached payload written by the timer trigger. If no cache exists it returns `204 No Content`.

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

The repository includes `.github/workflows/ci.yml` which runs PSScriptAnalyzer, Pester unit tests, and deploys the function app using OIDC. To enable the workflow:

1. Create an Azure AD application with federated credentials for your GitHub repository (Azure portal → Entra ID → App registrations → *Your app* → Certificates & secrets → Federated credentials).
2. Grant the app permissions to deploy (e.g. `Website Contributor` on the Function App resource group and `Storage Blob Data Contributor` on the storage account if needed).
3. In GitHub repository settings add the following secrets/variables:
   - `AZURE_CLIENT_ID` – The application (client) ID from Azure AD.
   - `AZURE_TENANT_ID` – The tenant ID.
   - `AZURE_SUBSCRIPTION_ID` – Subscription used for deployment.
   - `AZURE_RESOURCE_GROUP` – Resource group containing the Function App.
   - `FUNCTION_APP_NAME` – Name of the Function App instance.
4. Push to `master` to execute linting, tests, and deployment.

The workflow packages the `src/` directory and relies on `WEBSITE_RUN_FROM_PACKAGE=1` for zero-downtime deployments.

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
