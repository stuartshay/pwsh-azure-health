# GitHub Actions Azure Authentication Setup

This guide provides step-by-step instructions for setting up Azure authentication for GitHub Actions workflows using OpenID Connect (OIDC) federated credentials.

## Overview

The repository includes several GitHub Actions workflows that require Azure authentication:

- **`ci.yml`** - Continuous integration with linting, testing, and deployment
- **`infrastructure-deploy.yml`** - Deploy infrastructure using Bicep templates
- **`infrastructure-destroy.yml`** - Destroy infrastructure and resource groups
- **`infrastructure-whatif.yml`** - Preview infrastructure changes on pull requests

All workflows use **OIDC federated credentials** for authentication, which is more secure than storing client secrets in GitHub.

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository:

| Secret Name | Description | Used By |
|-------------|-------------|---------|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID | All workflows |
| `AZURE_TENANT_ID` | Azure AD tenant ID | All workflows |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | All workflows |
| `AZURE_RESOURCE_GROUP` | Resource group for production deployments | `ci.yml` |
| `FUNCTION_APP_NAME` | Function App name for production | `ci.yml` |

## Prerequisites

Before you begin, ensure you have:

- An Azure subscription with appropriate permissions
- Azure CLI installed and authenticated (`az login`)
- Owner or User Access Administrator role on the Azure subscription
- Admin access to your GitHub repository

## Setup Instructions

### Step 1: Set Variables

Set the following variables in your terminal:

```bash
# GitHub repository information
GITHUB_ORG="stuartshay"
GITHUB_REPO="pwsh-azure-health"

# Azure AD application name
APP_NAME="github-pwsh-azure-health"

# Get your Azure subscription and tenant IDs
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID: $TENANT_ID"
```

### Step 2: Create Azure AD Application

Create an Azure AD application for GitHub Actions authentication:

```bash
# Create the application
az ad app create --display-name "$APP_NAME"

# Get the application ID
APP_ID=$(az ad app list --display-name "$APP_NAME" --query [0].appId -o tsv)
echo "Application ID (AZURE_CLIENT_ID): $APP_ID"
```

### Step 3: Create Service Principal

Create a service principal for the application:

```bash
# Create service principal
az ad sp create --id "$APP_ID"

# Verify it was created
az ad sp show --id "$APP_ID" --query "{DisplayName:displayName, AppId:appId, ObjectId:id}"
```

### Step 4: Configure Federated Credentials

Configure federated credentials for different GitHub contexts (branches and pull requests):

#### For the master branch

```bash
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-pwsh-azure-health-master",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':ref:refs/heads/master",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - master branch"
  }'
```

#### For the develop branch

```bash
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-pwsh-azure-health-develop",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - develop branch"
  }'
```

#### For pull requests

```bash
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-pwsh-azure-health-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':pull_request",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - pull requests"
  }'
```

#### For environment deployments (optional)

If you're using GitHub environments (dev, prod):

```bash
# For dev environment
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-pwsh-azure-health-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':environment:dev",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - dev environment"
  }'

# For prod environment
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-pwsh-azure-health-env-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'"$GITHUB_ORG"'/'"$GITHUB_REPO"':environment:prod",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "GitHub Actions - prod environment"
  }'
```

### Step 5: Assign Azure Permissions

The service principal needs permissions to manage Azure resources.

#### Option A: Subscription-level Contributor (Recommended for simplicity)

This allows the workflows to create and manage resource groups:

```bash
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

echo "✅ Assigned Contributor role at subscription level"
```

#### Option B: Resource Group-level Contributor (More restrictive)

If you prefer to limit permissions to specific resource groups:

```bash
# For dev environment
az group create --name rg-azure-health-dev --location eastus

az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-azure-health-dev"

# For prod environment
az group create --name rg-azure-health-prod --location eastus

az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-azure-health-prod"

echo "✅ Assigned Contributor role at resource group level"
```

**Note:** If using resource group-level permissions, the `infrastructure-deploy.yml` workflow's step to create resource groups will fail. You'll need to create them manually first.

### Step 6: Configure GitHub Secrets

Add the secrets to your GitHub repository:

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each of the following:

```bash
# Display the values you need to add
echo ""
echo "=== GitHub Secrets Configuration ==="
echo ""
echo "Add these secrets at: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "AZURE_CLIENT_ID: $APP_ID"
echo "AZURE_TENANT_ID: $TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID"
echo ""
echo "For ci.yml workflow, also add (after infrastructure is deployed):"
echo "AZURE_RESOURCE_GROUP: rg-azure-health-prod"
echo "FUNCTION_APP_NAME: <your-function-app-name>"
echo ""
```

Or use the GitHub CLI:

```bash
# Install GitHub CLI if not already installed
# https://cli.github.com/

# Authenticate with GitHub
gh auth login

# Add secrets
gh secret set AZURE_CLIENT_ID --body "$APP_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"

echo "✅ GitHub secrets configured"
```

### Step 7: Verify Setup

#### List federated credentials

```bash
az ad app federated-credential list --id "$APP_ID" --query "[].{Name:name, Subject:subject}"
```

#### List role assignments

```bash
az role assignment list --assignee "$APP_ID" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
```

#### Test GitHub Actions

1. Create a pull request that modifies files in `infrastructure/`
2. The `infrastructure-whatif.yml` workflow should run automatically
3. Check the workflow logs to ensure Azure authentication succeeds
4. Review the what-if preview comment on your PR

## Summary of Permissions

The configured service principal has:

- **Azure AD Application**: Federated credentials for GitHub Actions OIDC
- **Azure RBAC**: Contributor role on subscription or resource groups
- **GitHub Secrets**: Stored securely in repository settings

## Security Best Practices

✅ **No client secrets** - Uses OIDC federated credentials  
✅ **Least privilege** - Only Contributor role, scoped appropriately  
✅ **Audit trail** - All actions logged in Azure Activity Log  
✅ **Environment protection** - Configure GitHub environment protection rules for prod  
✅ **Credential rotation** - No secrets to rotate; federated credentials use short-lived tokens  

## Troubleshooting

### Error: "Login failed with Error: Unable to get OIDC token"

**Cause:** Federated credential not configured for the branch/PR context.

**Solution:** Ensure you've created federated credentials for all contexts where workflows run (master, develop, pull_request, environments).

### Error: "The client does not have authorization to perform action"

**Cause:** Insufficient Azure permissions.

**Solution:** 
1. Verify role assignment: `az role assignment list --assignee "$APP_ID"`
2. Ensure the service principal has Contributor role
3. Check the scope matches where you're trying to create resources

### Error: "Resource group not found"

**Cause:** Using resource group-level permissions but group doesn't exist.

**Solution:** 
1. Create the resource group manually: `az group create --name <name> --location eastus`
2. Or grant subscription-level Contributor role

### GitHub Secrets not available in workflow

**Cause:** Secrets not configured or typo in secret name.

**Solution:**
1. Verify secrets exist: Settings → Secrets and variables → Actions
2. Check secret names match exactly (case-sensitive)
3. For forked repos, secrets must be re-added to the fork

## Additional Resources

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)

## Cleanup

To remove the Azure AD application and service principal:

```bash
# Delete the application (this also deletes the service principal)
az ad app delete --id "$APP_ID"

# Remove role assignments (if app wasn't deleted)
az role assignment delete --assignee "$APP_ID"
```

To remove GitHub secrets:

```bash
# Using GitHub CLI
gh secret remove AZURE_CLIENT_ID --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret remove AZURE_TENANT_ID --repo "$GITHUB_ORG/$GITHUB_REPO"
gh secret remove AZURE_SUBSCRIPTION_ID --repo "$GITHUB_ORG/$GITHUB_REPO"
```

Or manually via GitHub Settings → Secrets and variables → Actions.
