# Infrastructure Scripts

This folder contains scripts for Azure infrastructure management, deployment, and verification.

## Architecture

This project uses a **shared infrastructure pattern** with:
- **Shared Resource Group** (`rg-azure-health-shared`): Contains permanent User-Assigned Managed Identity used by multiple projects
- **Project Resource Groups** (`rg-azure-health-dev`, `rg-azure-health-prod`): Contains project-specific resources that can be destroyed/recreated

See [docs/SHARED_INFRASTRUCTURE.md](../../docs/SHARED_INFRASTRUCTURE.md) for full architecture details.

## Available Scripts

### setup-shared-identity.ps1 / setup-shared-identity.sh

**Creates shared Azure infrastructure for User-Assigned Managed Identity.**

**Purpose:**
Sets up permanent shared resources in `rg-azure-health-shared` that persist across project resource group deletions.

**Usage:**
```powershell
# PowerShell
./setup-shared-identity.ps1

# With custom location
./setup-shared-identity.ps1 -Location westus2

# Preview changes without applying
./setup-shared-identity.ps1 -WhatIf

# Bash
./setup-shared-identity.sh
./setup-shared-identity.sh --location westus2 --whatif
```

**What it creates:**
- Resource Group: `rg-azure-health-shared` (with CanNotDelete lock)
- User-Assigned Managed Identity: `id-azurehealth-shared`
- RBAC role assignments:
  - Reader (subscription scope) - for Service Health queries
  - Monitoring Reader (subscription scope) - for monitoring data
- Identity information saved to `shared-identity-info.json`

**Features:**
- Idempotent - safe to run multiple times
- Applies resource lock to prevent accidental deletion
- Colored output with progress indicators
- Exports identity details for project deployments
- What-If mode for previewing changes

**Prerequisites:**
- Azure CLI installed and authenticated
- Appropriate permissions to create resources and assign roles at subscription scope
- **Run this ONCE per subscription** before deploying projects

**⚠️ IMPORTANT:** This resource group should NEVER be deleted as multiple projects depend on it.

### deploy-bicep.ps1

**Deploys project-specific Azure resources using Bicep templates.**

**Usage:**
```powershell
# Deploy with defaults (uses shared identity from shared-identity-info.json)
./deploy-bicep.ps1

# Deploy to specific environment
./deploy-bicep.ps1 -Environment prod -Location westus2

# Deploy with custom parameters
./deploy-bicep.ps1 -ParametersFile ../infrastructure/main.bicepparam
```

**What it deploys:**
- Resource Group with project tagging
- Storage Account (Standard_LRS, TLS 1.2+, private blob access)
- Application Insights (90-day retention)
- Function App (PowerShell 7.4, Consumption plan)
- User-Assigned Managed Identity association
- RBAC role assignments:
  - Storage Blob Data Contributor (storage scope) - for cache access

**Features:**
- Validates shared infrastructure exists before deployment
- Automatically retrieves User-Assigned Managed Identity Resource ID
- Comprehensive error handling and validation
- Colored output with deployment progress
- Post-deployment verification

**Prerequisites:**
- Azure CLI installed and authenticated
- Shared infrastructure created (run `setup-shared-identity.ps1` first)
- Valid Bicep templates in `../../infrastructure/`

### provision-infrastructure.ps1

**Provisions all Azure resources required for the Health Monitoring Function App.**

**Usage:**
```powershell
# Provision with defaults from .env file
./provision-infrastructure.ps1

# Provision for production environment
./provision-infrastructure.ps1 -Environment prod -Location westus2

# Provision with custom resource group
./provision-infrastructure.ps1 -ResourceGroup my-custom-rg -Location eastus2

# Skip RBAC assignments (if you lack permissions)
./provision-infrastructure.ps1 -SkipRoleAssignments
```

**What it creates:**
- Resource Group with environment tagging
- Storage Account (Standard_LRS, TLS 1.2+, private blob access)
- Application Insights (90-day retention)
- Function App (PowerShell 7.4, Consumption plan)
- System-assigned Managed Identity
- RBAC role assignments:
  - Reader (subscription scope) - for Service Health queries
  - Monitoring Reader (subscription scope) - for monitoring data
  - Storage Blob Data Contributor (storage scope) - for cache access

**Features:**
- Idempotent - safe to run multiple times
- Loads configuration from `.env` file
- Generates unique resource names with environment suffixes
- Comprehensive error handling and validation
- Colored output with progress indicators
- Configures all required application settings

**Prerequisites:**
- Azure CLI installed and authenticated
- Appropriate permissions to create resources and assign roles
- Valid `.env` file (or use parameters to override)

### setup-keyvault-access.ps1

**Grants managed identities RBAC access to the shared Key Vault.**

**Purpose:**
Configures permissions for the shared Key Vault (`kv-tsazurehealth`) to allow:
- Shared managed identity (`id-azurehealth-shared`) to read secrets
- Frontend app identities (`id-tsazurehealth-dev/prod`) to read secrets
- GitHub Actions service principal to write secrets (optional)

**Usage:**
```powershell
# Grant access to managed identities
./setup-keyvault-access.ps1

# Also grant access to GitHub Actions
./setup-keyvault-access.ps1 -GrantGitHubActions -GitHubActionsAppId "12345678-1234-1234-1234-123456789012"
```

**RBAC Roles Assigned:**
- **Key Vault Secrets User**: Read-only access for managed identities
- **Key Vault Secrets Officer**: Read/write access for GitHub Actions

**Features:**
- Idempotent - safe to run multiple times
- Validates resources exist before assigning roles
- Skips existing role assignments
- Colored output with progress indicators
- Displays current role assignments after completion

**Prerequisites:**
- Azure CLI installed and authenticated
- Shared Key Vault exists (`kv-tsazurehealth` in `rg-azure-health-shared`)
- Appropriate permissions to assign RBAC roles

**When to run:**
- After initial infrastructure deployment
- When adding new managed identities
- When troubleshooting Key Vault access issues

**Cross-Project Configuration:**

The GitHub Actions deployment workflow automatically updates the following secrets in the shared Key Vault:
- `function-app-url-dev`: Backend Function App URL for dev environment
- `function-app-url-prod`: Backend Function App URL for prod environment

Frontend applications can retrieve these secrets using their managed identity:
```bash
az keyvault secret show \
  --vault-name kv-tsazurehealth \
  --name function-app-url-dev \
  --query value -o tsv
```

### check-azure-health-access.ps1

Verifies access to the Azure Resource Health API and checks prerequisites.

**Usage:**
```powershell
./check-azure-health-access.ps1
```

**What it checks:**
- Azure CLI authentication status
- Azure Resource Graph extension installation
- Microsoft.ResourceHealth provider registration
- Service Health query access via Azure Resource Graph
- RBAC role assignments (Reader/Contributor/Owner)

**Prerequisites:**
- Azure CLI installed and authenticated (`az login`)
- At least Reader role on the target subscription

**If issues are found:**
- Install Resource Graph extension: `az extension add --name resource-graph`
- Register provider: `az provider register --namespace Microsoft.ResourceHealth`
- Verify RBAC: `az role assignment list --assignee <user-id> --subscription <subscription-id>`

### validate-shared-setup.ps1

**Validates shared infrastructure configuration and health.**

**Usage:**
```powershell
./validate-shared-setup.ps1
```

**What it validates:**
- Shared resource group exists (`rg-azure-health-shared`)
- User-Assigned Managed Identity exists and is accessible
- RBAC roles are correctly assigned (Reader, Monitoring Reader)
- Resource lock is applied (CanNotDelete)
- Identity propagation to Microsoft Entra ID
- Shared identity info file exists and is current

**Features:**
- Comprehensive validation with detailed status messages
- Returns exit code 0 for success, 1 for failure
- Useful for CI/CD pipeline validation gates
- Colored output with pass/fail indicators

**Prerequisites:**
- Azure CLI installed and authenticated
- Shared infrastructure created (run `setup-shared-identity.ps1` first)

## Migration Guide

If migrating from System-Assigned Managed Identity to User-Assigned Managed Identity:

1. **Setup shared infrastructure** (one-time per subscription):
   ```powershell
   ./setup-shared-identity.ps1
   ```

2. **Update deployment scripts** to reference shared identity:
   ```powershell
   # Identity Resource ID will be in shared-identity-info.json
   ./deploy-bicep.ps1
   ```

3. **Verify deployment** uses User-Assigned Managed Identity:
   ```powershell
   ./validate-shared-setup.ps1
   az functionapp show --name <function-app-name> --resource-group <rg> --query identity
   ```

See [docs/MIGRATION_GUIDE.md](../../docs/MIGRATION_GUIDE.md) for complete migration instructions.

## Related Folders

- `../deployment/` - Deployment scripts for Azure Functions
- `../local/` - Local development environment setup scripts
- `../ci/` - Continuous integration scripts
