# Shared Infrastructure Architecture

This document describes the shared infrastructure pattern used across Azure Health Monitoring projects.

## Table of Contents
- [Overview](#overview)
- [Architecture Diagram](#architecture-diagram)
- [Resource Groups](#resource-groups)
- [Managed Identity Strategy](#managed-identity-strategy)
- [Resource Lifecycle](#resource-lifecycle)
- [Security Model](#security-model)
- [Multi-Project Support](#multi-project-support)
- [Tag Strategy](#tag-strategy)
- [Deletion and Recreation](#deletion-and-recreation)

## Overview

The Azure Health Monitoring projects use a **shared infrastructure pattern** where:
- **Permanent resources** (Managed Identities, Key Vaults) live in a locked shared resource group
- **Project-specific resources** (Function Apps, Storage Accounts) live in project resource groups that can be destroyed/recreated

This pattern enables:
- ✅ **Clean environment recreation** - delete project resource groups without losing identities
- ✅ **Multi-project sharing** - multiple projects can share common infrastructure
- ✅ **Security isolation** - each project has its own User-Assigned Managed Identity
- ✅ **Cost tracking** - project-specific resources are tagged for billing separation
- ✅ **CI/CD flexibility** - tear down and rebuild dev/test environments easily

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        SUBSCRIPTION                              │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ rg-azure-health-shared (PERMANENT - LOCKED)              │  │
│  │                                                           │  │
│  │  ├─ id-azurehealth-shared (User-Assigned MI)            │  │
│  │  │   ├─ Role: Reader (subscription scope)               │  │
│  │  │   └─ Role: Monitoring Reader (subscription scope)    │  │
│  │  │                                                        │  │
│  │  ├─ kv-azurehealth-shared (Key Vault) [FUTURE]          │  │
│  │  │   └─ Stores: certificates, secrets, API keys         │  │
│  │  │                                                        │  │
│  │  └─ id-github-azurehealth (GitHub Actions MI) [FUTURE]  │  │
│  │      └─ Role: Contributor (on project RGs only)          │  │
│  │                                                           │  │
│  │  🔒 Lock: CanNotDelete                                   │  │
│  │  🏷️  Tags: lifecycle=permanent, sharedBy=*               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ rg-azure-health-dev (PROJECT-SPECIFIC - RECREATABLE)     │  │
│  │                                                           │  │
│  │  ├─ func-azurehealth-dev (Function App)                 │  │
│  │  │   └─ Uses: id-azurehealth-shared                     │  │
│  │  │                                                        │  │
│  │  ├─ st-azurehealth-dev (Storage Account)                │  │
│  │  │   └─ Role: Storage Blob Data Contributor             │  │
│  │  │       (assigned to id-azurehealth-shared)            │  │
│  │  │                                                        │  │
│  │  ├─ appi-azurehealth-dev (Application Insights)         │  │
│  │  │                                                        │  │
│  │  └─ plan-azurehealth-dev (App Service Plan)             │  │
│  │                                                           │  │
│  │  🏷️  Tags: project=pwsh-azure-health, env=dev            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ rg-azure-health-prod (PROJECT-SPECIFIC - RECREATABLE)    │  │
│  │                                                           │  │
│  │  [Same structure as dev, with prod suffix]               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Resource Groups

### Shared Resource Group: `rg-azure-health-shared`

**Purpose:** Contains permanent infrastructure shared across all projects and environments.

**Lifecycle:**
- Created once per subscription
- **NEVER deleted** - protected by CanNotDelete lock
- Persists across all project deployments and deletions

**Contents:**
- User-Assigned Managed Identities (one per environment)
- Key Vault for shared secrets (future)
- GitHub Actions identity for CI/CD (future)

**Location:** Same as primary project deployment (typically `eastus`)

**Tags:**
```json
{
  "purpose": "shared-infrastructure",
  "lifecycle": "permanent",
  "project": "azure-health-monitoring",
  "sharedBy": "pwsh-azure-health,ts-azure-health"
}
```

**Protection:**
- CanNotDelete resource lock applied
- Requires lock removal for any deletion
- Documented in runbooks as critical infrastructure

### Project Resource Groups: `rg-azure-health-{env}`

**Purpose:** Contains environment-specific project resources.

**Lifecycle:**
- Created per project deployment
- Can be deleted and recreated without losing identities
- Destroyed during environment cleanup

**Contents:**
- Function App
- Storage Account
- Application Insights
- App Service Plan (Consumption)

**Environment Patterns:**
- `rg-azure-health-dev` - Development
- `rg-azure-health-test` - Testing/QA
- `rg-azure-health-prod` - Production

**Tags:**
```json
{
  "project": "pwsh-azure-health",
  "environment": "dev|test|prod",
  "managedBy": "bicep",
  "costCenter": "engineering"
}
```

## Managed Identity Strategy

### Why User-Assigned Managed Identity?

**Problem with System-Assigned Managed Identity:**
- ❌ Created and destroyed with Function App lifecycle
- ❌ Role assignments lost when Function App is deleted
- ❌ Principal ID changes on each recreation
- ❌ Requires re-assigning all RBAC roles after every deployment

**Benefits of User-Assigned Managed Identity:**
- ✅ Persists independently of Function App
- ✅ Role assignments survive resource group deletions
- ✅ Same Principal ID across deployments
- ✅ Can be shared across multiple apps (if needed)
- ✅ Simplifies CI/CD pipelines

### Identity Naming Convention

```
id-azurehealth-shared
```

**Current Implementation:**
- `id-azurehealth-shared` - Shared managed identity used across all environments and projects

**Note:** Currently, a single User-Assigned Managed Identity is used across all environments (dev, staging, prod). The "shared" aspect refers to both the resource group and the managed identity being shared across projects and environments. This simplifies management and reduces costs. If per-environment identities are required in the future, the naming convention would follow: `id-{product}-{environment}`.

### RBAC Assignments

#### Subscription-Scoped Roles (Assigned Once)

Assigned to User-Assigned Managed Identity in shared RG:

| Role | Scope | Purpose |
|------|-------|---------|
| Reader | Subscription | Query Azure Service Health and Resource Health APIs |
| Monitoring Reader | Subscription | Read monitoring data and metrics |

#### Resource-Scoped Roles (Assigned Per Deployment)

Assigned during project deployment:

| Role | Scope | Purpose |
|------|-------|---------|
| Storage Blob Data Contributor | Storage Account | Read/write blob cache data |

## Resource Lifecycle

### Initial Setup (One-Time)

```bash
# 1. Create shared infrastructure
cd scripts/infrastructure
./setup-shared-identity.ps1

# 2. Verify setup
./validate-shared-setup.ps1

# 3. Save identity info
cat shared-identity-info.json
```

### Project Deployment (Repeatable)

```bash
# Deploy project resources
./deploy-bicep.ps1 -Environment dev

# Function App automatically uses shared identity
# Storage role assigned to shared identity
```

### Environment Cleanup (Safe)

```bash
# Delete project resource group (identity survives)
az group delete --name rg-azure-health-dev --yes

# Redeploy - uses same identity, roles already assigned
./deploy-bicep.ps1 -Environment dev
```

### Full Deletion (Rare)

```bash
# 1. Delete all project resource groups
az group delete --name rg-azure-health-dev --yes
az group delete --name rg-azure-health-prod --yes

# 2. Remove shared RG lock
az lock delete --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared

# 3. Delete shared resource group
az group delete --name rg-azure-health-shared --yes

# 4. Re-run setup from scratch
./setup-shared-identity.ps1
```

## Security Model

### Identity Permissions

**Subscription-Level Access (Read-Only):**
- Service Health events
- Resource Health status
- Monitoring metrics
- No write permissions at subscription level

**Resource-Level Access (Read-Write):**
- Storage Account blob operations (cache only)
- Application Insights telemetry write
- No secrets or Key Vault access (unless explicitly granted)

### Least Privilege Principle

Each identity has **minimum required permissions**:
- No Contributor or Owner roles
- No Key Vault access (secrets managed via Key Vault references)
- No subscription write permissions
- Storage access scoped to specific storage account

### Security Boundaries

```
┌─────────────────────────────────────────┐
│ Managed Identity (id-azurehealth-dev)   │
├─────────────────────────────────────────┤
│ CAN:                                     │
│  ✅ Read Service Health                  │
│  ✅ Read Resource Health                 │
│  ✅ Read monitoring metrics              │
│  ✅ Write to assigned storage account    │
│  ✅ Write to Application Insights        │
├─────────────────────────────────────────┤
│ CANNOT:                                  │
│  ❌ Create/delete Azure resources        │
│  ❌ Modify RBAC assignments              │
│  ❌ Access other storage accounts        │
│  ❌ Access Key Vault (without grant)     │
│  ❌ Impersonate users                    │
└─────────────────────────────────────────┘
```

## Multi-Project Support

### Supported Projects

The shared infrastructure supports multiple projects:

| Project | Language | Repository | Identity |
|---------|----------|------------|----------|
| pwsh-azure-health | PowerShell 7.4 | This repo | id-azurehealth-dev |
| ts-azure-health | TypeScript/Node.js | Separate repo | id-tsazurehealth-dev |

### Resource Isolation

Each project:
- ✅ Has its own project resource group
- ✅ Has its own User-Assigned Managed Identity
- ✅ Has its own storage account
- ✅ Can be deleted independently
- ✅ Uses shared Key Vault for secrets (future)

### Shared Resources

All projects share:
- Resource group (`rg-azure-health-shared`)
- GitHub Actions identity (for CI/CD)
- Key Vault (for certificates, API keys)

## Tag Strategy

### Shared Resource Tags

```json
{
  "purpose": "shared-infrastructure",
  "lifecycle": "permanent",
  "project": "azure-health-monitoring",
  "sharedBy": "pwsh-azure-health,ts-azure-health",
  "managedBy": "script"
}
```

### Project Resource Tags

```json
{
  "project": "pwsh-azure-health",
  "environment": "dev",
  "lifecycle": "recreatable",
  "managedBy": "bicep",
  "costCenter": "engineering"
}
```

### Tag-Based Operations

```bash
# Find all pwsh-azure-health resources
az resource list --tag project=pwsh-azure-health

# Find all shared resources
az resource list --tag lifecycle=permanent

# Cost analysis by project
az consumption usage list --filter "tags/project eq 'pwsh-azure-health'"
```

## Deletion and Recreation

### Safe Deletion Pattern

Following the **ts-azure-health** pattern for infrastructure cleanup:

```bash
# 1. Remove resource locks
az lock delete --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared

# 2. Delete resources by project tag (preserves other projects)
az resource list \
  --tag project=pwsh-azure-health \
  --query '[].id' -o tsv | \
  xargs -I {} az resource delete --ids {}

# 3. Restore resource lock
az lock create \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared \
  --lock-type CanNotDelete
```

### Recreation After Deletion

```bash
# Shared RG exists, identity exists
# Just redeploy project resources
./deploy-bicep.ps1 -Environment dev

# Identity roles already assigned, no additional setup needed
```

### Greenfield Setup

Since this is a **greenfield deployment**, you can safely:
- Delete and recreate project resource groups
- Experiment with different configurations
- Test deployment pipelines
- No production workloads to preserve

## Best Practices

### ✅ DO

- Run `setup-shared-identity.ps1` once per subscription
- Use `validate-shared-setup.ps1` in CI/CD pipelines
- Tag all resources consistently
- Document any changes to shared infrastructure
- Test deletions in dev before prod
- Keep shared RG locked at all times

### ❌ DON'T

- Delete `rg-azure-health-shared` without coordination
- Remove resource locks without documented reason
- Assign unnecessary permissions to managed identities
- Hard-code Principal IDs in scripts (use Resource ID)
- Share storage accounts across projects
- Mix project resources in shared RG

## Troubleshooting

### Identity Not Found

```bash
# Verify shared RG exists
az group show --name rg-azure-health-shared

# Verify identity exists
az identity show \
  --name id-azurehealth-shared \
  --resource-group rg-azure-health-shared
```

### Permission Denied

```bash
# Check role assignments
az role assignment list \
  --assignee $(az identity show --name id-azurehealth-shared --resource-group rg-azure-health-shared --query principalId -o tsv) \
  --all

# Verify subscription-level access
az role assignment list \
  --scope /subscriptions/$(az account show --query id -o tsv) \
  --query "[?principalId=='<principal-id>']"
```

### Lock Preventing Changes

```bash
# List locks
az lock list --resource-group rg-azure-health-shared

# Temporarily remove lock (with approval)
az lock delete \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared

# Make changes...

# Restore lock
az lock create \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared \
  --lock-type CanNotDelete
```

## Future Enhancements

### Planned Additions to Shared RG

1. **Key Vault** (`kv-azurehealth-shared`)
   - Centralized secret management
   - Certificate storage
   - API key rotation

2. **GitHub Actions Identity** (`id-github-azurehealth`)
   - Federated credential for OIDC
   - Contributor role on project RGs only
   - No subscription-level permissions

3. **Log Analytics Workspace** (shared across projects)
   - Centralized logging
   - Cross-project queries
   - Unified monitoring dashboard

4. **Separate Repository** (`rg-azure-health-shared`)
   - Move setup scripts to dedicated repo
   - Version control for shared infrastructure
   - Independent deployment pipeline

## References

- [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) - Migration from System-Assigned MI
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment procedures
- [BEST_PRACTICES.md](./BEST_PRACTICES.md) - Security and operational best practices
- [Azure Managed Identities](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/)
- [Resource Locks](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
