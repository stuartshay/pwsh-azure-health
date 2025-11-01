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

The repository includes GitHub Actions workflows for infrastructure deployment and CI/CD:

#### Infrastructure Workflows

1. **`infrastructure-deploy.yml`** - Deploy infrastructure using Bicep templates
   - Manually triggered via workflow dispatch
   - Select environment (dev or prod)
   - Creates resource group `rg-azure-health-{environment}`
   - Deploys all Azure resources from `infrastructure/main.bicep`

2. **`infrastructure-destroy.yml`** - Destroy infrastructure
   - Manually triggered via workflow dispatch
   - Deletes entire resource group and all resources
   - Shows resource list before deletion

3. **`infrastructure-whatif.yml`** - Preview infrastructure changes
   - Automatically triggered on PRs modifying `infrastructure/**`
   - Posts what-if comparison as PR comment
   - Shows changes for both dev and prod environments

#### CI/CD Workflow

The `ci.yml` workflow runs PSScriptAnalyzer, Pester unit tests, and deploys the function code using OIDC.

#### Setup GitHub Secrets for Azure OIDC Authentication

To enable GitHub Actions workflows, configure Azure AD authentication using federated credentials (no secrets required):

##### 1. Create Azure AD Application

```bash
# Create the application
APP_NAME="github-pwsh-azure-health"
az ad app create --display-name $APP_NAME

# Get the application ID
APP_ID=$(az ad app list --display-name $APP_NAME --query [0].appId -o tsv)
echo "Application ID: $APP_ID"
```

##### 2. Create Federated Credentials

Configure federated credentials for the GitHub repository:

```bash
# Get your tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Create federated credential for main/master branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pwsh-azure-health-master",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:stuartshay/pwsh-azure-health:ref:refs/heads/master",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for develop branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pwsh-azure-health-develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:stuartshay/pwsh-azure-health:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pwsh-azure-health-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:stuartshay/pwsh-azure-health:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

##### 3. Assign Azure Permissions

Grant the application necessary permissions to deploy and manage resources:

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Create service principal for the app
az ad sp create --id $APP_ID

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp show --id $APP_ID --query id -o tsv)

# Assign Contributor role at subscription level (for creating resource groups)
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Alternative: Assign roles at specific resource group level
# For dev environment
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-azure-health-dev"

# For prod environment
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-azure-health-prod"
```

##### 4. Configure GitHub Secrets

Add the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AZURE_CLIENT_ID` | `<APP_ID from step 1>` | Azure AD application (client) ID |
| `AZURE_TENANT_ID` | `<TENANT_ID from step 2>` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `<SUBSCRIPTION_ID from step 3>` | Target Azure subscription ID |
| `AZURE_RESOURCE_GROUP` | `rg-azure-health-prod` | Resource group for prod deployments (for ci.yml) |
| `FUNCTION_APP_NAME` | `func-azure-health-prod` | Function app name (for ci.yml) |

```bash
# Display values for GitHub Secrets configuration
echo "=== GitHub Secrets Configuration ==="
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "Add these to: https://github.com/stuartshay/pwsh-azure-health/settings/secrets/actions"
```

##### 5. Test the Workflows

Once configured, you can:

- **Deploy infrastructure**: Go to Actions → Deploy Infrastructure → Run workflow → Select environment
- **Destroy infrastructure**: Go to Actions → Destroy Infrastructure → Run workflow → Select environment
- **Preview changes**: Create a PR modifying files in `infrastructure/` to see what-if preview
- **Deploy code**: Push to `master` branch to trigger linting, testing, and code deployment

##### Security Notes

- ✅ **No secrets stored**: OIDC uses federated credentials, no client secrets required
- ✅ **Least privilege**: Grant only necessary permissions to the service principal
- ✅ **Environment protection**: Configure environment protection rules in GitHub for prod deployments
- ✅ **Audit trail**: All deployments are logged in Azure Activity Log and GitHub Actions history

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
