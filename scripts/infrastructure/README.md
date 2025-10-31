# Infrastructure Scripts

This folder contains scripts for Azure infrastructure management, deployment, and verification.

## Available Scripts

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

## Planned Scripts

Additional infrastructure scripts will be added here for:
- Resource provisioning (Function App, Storage, Application Insights)
- RBAC role assignment automation
- Resource group management
- Managed identity configuration
- Network and security configuration

## Related Folders

- `../deployment/` - Deployment scripts for Azure Functions
- `../local/` - Local development environment setup scripts
- `../ci/` - Continuous integration scripts
