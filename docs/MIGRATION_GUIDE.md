# Migration Guide: System-Assigned to User-Assigned Managed Identity

This guide provides step-by-step instructions for migrating from System-Assigned Managed Identity to User-Assigned Managed Identity in the shared resource group pattern.

## Table of Contents
- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Pre-Migration Checklist](#pre-migration-checklist)
- [Migration Steps](#migration-steps)
- [Verification](#verification)
- [Rollback Procedure](#rollback-procedure)
- [Troubleshooting](#troubleshooting)

## Overview

### Current Architecture (System-Assigned MI)

```
┌──────────────────────────────────────────┐
│ rg-azure-health-dev                      │
│                                           │
│  ├─ func-azurehealth-dev                 │
│  │   └─ System-Assigned MI               │
│  │       ├─ Reader (subscription)        │
│  │       ├─ Monitoring Reader (sub)      │
│  │       └─ Storage Blob Data Contributor│
│  │                                        │
│  └─ st-azurehealth-dev                   │
│                                           │
│  ⚠️  Deleting Function App loses roles!  │
└──────────────────────────────────────────┘
```

### Target Architecture (User-Assigned MI)

```
┌──────────────────────────────────────────┐
│ rg-azure-health-shared (LOCKED)          │
│                                           │
│  └─ id-azurehealth-shared                │
│      ├─ Reader (subscription)            │
│      └─ Monitoring Reader (subscription) │
└──────────────────────────────────────────┘
              │
              │ Referenced by
              ▼
┌──────────────────────────────────────────┐
│ rg-azure-health-dev (RECREATABLE)        │
│                                           │
│  ├─ func-azurehealth-dev                 │
│  │   └─ Uses: id-azurehealth-shared      │
│  │                                        │
│  └─ st-azurehealth-dev                   │
│      └─ Storage Blob Data Contributor    │
│          (assigned to shared MI)         │
│                                           │
│  ✅ Can delete/recreate, roles persist!  │
└──────────────────────────────────────────┘
```

### Migration Impact

| Aspect | Before | After |
|--------|--------|-------|
| Identity Type | System-Assigned | User-Assigned |
| Identity Location | Function App resource | Shared resource group |
| Identity Lifecycle | Tied to Function App | Independent |
| Deletion Impact | Roles lost | Roles persist |
| Principal ID | Changes on recreate | Stays consistent |
| Role Assignments | Must reassign after delete | One-time assignment |
| Resource Groups | 1 (project RG) | 2 (shared + project) |

## Prerequisites

### Required Tools

- Azure CLI (`az`) version 2.50.0 or later
- PowerShell 7.0 or later (for `.ps1` scripts)
- Bash 4.0 or later (for `.sh` scripts)
- `jq` (for JSON parsing in Bash scripts)

### Required Permissions

You need the following Azure RBAC roles:

| Role | Scope | Purpose |
|------|-------|---------|
| Owner or Contributor | Subscription | Create resource groups and resources |
| User Access Administrator or Owner | Subscription | Assign RBAC roles |

**Verify permissions:**
```bash
# Check your subscription-level roles
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope /subscriptions/$(az account show --query id -o tsv) \
  --query '[].{Role:roleDefinitionName, Scope:scope}'
```

### Backup Current Configuration

Before starting migration, save current configuration:

```bash
# 1. Export Function App settings
az functionapp config appsettings list \
  --name <function-app-name> \
  --resource-group rg-azure-health-dev \
  > backup-appsettings.json

# 2. Export current identity info
az functionapp show \
  --name <function-app-name> \
  --resource-group rg-azure-health-dev \
  --query identity \
  > backup-identity.json

# 3. Export current role assignments
PRINCIPAL_ID=$(cat backup-identity.json | jq -r '.principalId')
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --all \
  > backup-roles.json

# 4. Verify backup files exist
ls -lh backup-*.json
```

## Pre-Migration Checklist

- [ ] Azure CLI authenticated (`az login`)
- [ ] Correct subscription selected (`az account show`)
- [ ] Required permissions verified (Owner/Contributor + User Access Administrator)
- [ ] Backup files created (`backup-*.json`)
- [ ] Maintenance window scheduled (if production)
- [ ] Stakeholders notified (if production)
- [ ] Tested in non-production environment first

## Migration Steps

### Phase 1: Create Shared Infrastructure

**Duration:** ~5 minutes

#### Step 1.1: Run Shared Infrastructure Setup

```bash
cd scripts/infrastructure

# PowerShell
./setup-shared-identity.ps1

# OR Bash
./setup-shared-identity.sh
```

**Expected Output:**
```
==========================================================
  Azure Health Monitoring - Shared Infrastructure Setup
==========================================================

[OK] Authenticated as: user@example.com
  Subscription: BizSpark
  Subscription ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Creating shared resource group...
[OK] Created resource group: rg-azure-health-shared

Creating User-Assigned Managed Identity...
[OK] Created Managed Identity: id-azurehealth-shared
  Principal ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
  Client ID: zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
  Resource ID: /subscriptions/.../id-azurehealth-shared

Assigning RBAC roles at subscription scope...
  [OK] Reader role assigned
  [OK] Monitoring Reader role assigned

Applying resource lock...
  [OK] Applied lock: DoNotDelete-SharedInfrastructure

Identity information saved to: shared-identity-info.json

==========================================================
  Setup Complete!
==========================================================
```

#### Step 1.2: Validate Shared Infrastructure

```bash
./validate-shared-setup.ps1
```

**Expected Output:**
```
[OK] Resource group exists
[OK] Managed Identity exists
[OK] Reader role assigned
[OK] Monitoring Reader role assigned
[OK] Resource lock applied
[OK] Identity info file exists
```

#### Step 1.3: Save Identity Resource ID

```bash
# PowerShell
$identityId = (Get-Content shared-identity-info.json | ConvertFrom-Json).resourceId
Write-Host "Identity Resource ID: $identityId"

# Bash
IDENTITY_ID=$(jq -r '.resourceId' shared-identity-info.json)
echo "Identity Resource ID: $IDENTITY_ID"
```

**Save this value** - you'll need it for the next phase.

### Phase 2: Update Bicep Templates

**Duration:** ~10 minutes

#### Step 2.1: Update main.bicep

Navigate to `infrastructure/main.bicep` and make the following changes:

**Find (lines ~10-15):**
```bicep
@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod)')
param environment string = 'dev'
```

**Add after environment parameter:**
```bicep
@description('Resource ID of the User-Assigned Managed Identity')
param managedIdentityResourceId string
```

**Find (lines ~119-121):**
```bicep
identity: {
  type: 'SystemAssigned'
}
```

**Replace with:**
```bicep
identity: {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${managedIdentityResourceId}': {}
  }
}
```

**Find (lines ~180-190) - remove Storage Blob Data Contributor assignment:**
```bicep
// Remove this entire resource block
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, functionApp.id, 'Storage Blob Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.BuiltIn/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
```

**Storage role will be assigned by deploy script instead.**

#### Step 2.2: Update main.bicepparam

Navigate to `infrastructure/main.bicepparam` and update:

**Find:**
```bicep
using './main.bicep'

param location = 'eastus'
param environment = 'dev'
```

**Add:**
```bicep
// Resource ID of the User-Assigned Managed Identity from shared resource group
// This value is automatically passed during deployment by deploy-bicep.ps1
param managedIdentityResourceId = ''
```

> **Note:** You do **not** need to manually update the placeholder value. The deployment script (`deploy-bicep.ps1`) automatically reads the managed identity resource ID from `shared-identity-info.json` and passes it as a parameter during deployment. The empty string is just a default for the parameter file.

#### Step 2.3: Update roleAssignments.bicep

Navigate to `infrastructure/modules/roleAssignments.bicep`:

**Find (line ~10):**
```bicep
@description('Principal ID of the System-Assigned Managed Identity')
param principalId string
```

**Update to:**
```bicep
@description('Principal ID of the User-Assigned Managed Identity')
param principalId string
```

### Phase 3: Update Deployment Script

**Duration:** ~15 minutes

The `deploy-bicep.ps1` script needs updates to:
1. Validate shared infrastructure exists
2. Retrieve User-Assigned Managed Identity Resource ID
3. Pass identity info to Bicep deployment
4. Assign Storage Blob Data Contributor role

**Find (lines ~60-70) - after parameter validation:**
```powershell
# Validate required tools
Write-Message 'Validating prerequisites...' -Color Cyan
```

**Add before this section:**
```powershell
# Validate shared infrastructure exists
Write-Message 'Validating shared infrastructure...' -Color Cyan

$sharedRgExists = az group exists --name 'rg-azure-health-shared' | ConvertFrom-Json
if (-not $sharedRgExists) {
    Write-Error @"
Shared resource group 'rg-azure-health-shared' not found.
Please run setup-shared-identity.ps1 first:

    cd scripts/infrastructure
    ./setup-shared-identity.ps1
"@
    exit 1
}

# Retrieve User-Assigned Managed Identity Resource ID
$identityInfoFile = Join-Path $PSScriptRoot 'shared-identity-info.json'
if (-not (Test-Path $identityInfoFile)) {
    Write-Error @"
Identity info file not found: $identityInfoFile
Please run setup-shared-identity.ps1 first to generate this file.
"@
    exit 1
}

$identityInfo = Get-Content $identityInfoFile | ConvertFrom-Json
$managedIdentityResourceId = $identityInfo.resourceId
$managedIdentityPrincipalId = $identityInfo.principalId

Write-Message "[OK] Found shared identity: $($identityInfo.identityName)" -Color Green
Write-Message "  Principal ID: $managedIdentityPrincipalId" -Color Gray
Write-Message "  Resource ID: $managedIdentityResourceId" -Color Gray
Write-Message ''
```

**Find deployment command (lines ~120-130):**
```powershell
$deploymentResult = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $templateFile `
    --parameters $parametersFile `
    --parameters location=$Location environment=$Environment `
    --name "deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
    --output json
```

**Update to include managedIdentityResourceId parameter:**
```powershell
$deploymentResult = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file $templateFile `
    --parameters $parametersFile `
    --parameters location=$Location environment=$Environment `
    --parameters managedIdentityResourceId=$managedIdentityResourceId `
    --name "deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
    --output json
```

**Find end of deployment section, add storage role assignment:**
```powershell
# Assign Storage Blob Data Contributor role to managed identity
Write-Message 'Assigning storage permissions...' -Color Cyan

$deployment = $deploymentResult | ConvertFrom-Json
$storageAccountName = $deployment.properties.outputs.storageAccountName.value

$storageScope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

$existingAssignment = az role assignment list `
    --assignee $managedIdentityPrincipalId `
    --role 'Storage Blob Data Contributor' `
    --scope $storageScope `
    --query '[0].id' -o tsv

if ($existingAssignment) {
    Write-Message '[SKIP] Storage Blob Data Contributor role already assigned' -Color Yellow
} else {
    az role assignment create `
        --assignee $managedIdentityPrincipalId `
        --role 'Storage Blob Data Contributor' `
        --scope $storageScope | Out-Null
    Write-Message '[OK] Storage Blob Data Contributor role assigned' -Color Green
}
Write-Message ''
```

### Phase 4: Deploy Updated Infrastructure

**Duration:** ~5 minutes (deployment time)

#### Step 4.1: Deploy to Dev Environment

```bash
cd scripts/infrastructure
./deploy-bicep.ps1 -Environment dev
```

**Expected Output:**
```
Validating shared infrastructure...
[OK] Found shared identity: id-azurehealth-shared
  Principal ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
  Resource ID: /subscriptions/.../id-azurehealth-shared

Starting Bicep deployment...
Deployment running: deployment-20240115120000

Deployment completed successfully!
  Storage Account: stazhealthdev123
  Function App: func-azurehealth-dev

Assigning storage permissions...
[OK] Storage Blob Data Contributor role assigned
```

#### Step 4.2: Verify Function App Identity

```bash
# PowerShell
$funcApp = az functionapp show `
    --name func-azurehealth-dev `
    --resource-group rg-azure-health-dev | ConvertFrom-Json

Write-Host "Identity Type: $($funcApp.identity.type)"
Write-Host "User-Assigned Identities:"
$funcApp.identity.userAssignedIdentities | ConvertTo-Json

# Expected: type = "UserAssigned"
# Expected: userAssignedIdentities contains shared identity Resource ID
```

### Phase 5: Validate Migration

**Duration:** ~10 minutes

#### Step 5.1: Verify RBAC Assignments

```bash
# Get identity principal ID
PRINCIPAL_ID=$(jq -r '.principalId' scripts/infrastructure/shared-identity-info.json)

# List all role assignments
az role assignment list \
  --assignee $PRINCIPAL_ID \
  --all \
  --query '[].{Role:roleDefinitionName, Scope:scope}' \
  --output table

# Expected roles:
# - Reader (subscription scope)
# - Monitoring Reader (subscription scope)
# - Storage Blob Data Contributor (storage account scope)
```

#### Step 5.2: Test Function App

```bash
# Trigger Service Health function
az functionapp function keys list \
  --name func-azurehealth-dev \
  --resource-group rg-azure-health-dev \
  --function-name GetServiceHealth

# Use key to test endpoint
curl -X GET "https://func-azurehealth-dev.azurewebsites.net/api/GetServiceHealth?code=<function-key>"

# Expected: 200 OK with Service Health data
```

#### Step 5.3: Verify Storage Access

```bash
# Check blob access (should succeed)
az storage blob list \
  --account-name stazhealthdev123 \
  --container-name cache \
  --auth-mode login

# If function has run, should see cached data
```

#### Step 5.4: Test Resource Deletion/Recreation

```bash
# 1. Delete Function App
az functionapp delete \
  --name func-azurehealth-dev \
  --resource-group rg-azure-health-dev

# 2. Verify identity still exists
az identity show \
  --name id-azurehealth-shared \
  --resource-group rg-azure-health-shared

# 3. Verify roles still assigned
az role assignment list --assignee $PRINCIPAL_ID --all

# 4. Redeploy Function App
cd scripts/infrastructure
./deploy-bicep.ps1 -Environment dev

# 5. Verify Function App works immediately (no role reassignment needed)
curl -X GET "https://func-azurehealth-dev.azurewebsites.net/api/HealthCheck"
```

## Verification

### Post-Migration Checklist

- [ ] Shared resource group created (`rg-azure-health-shared`)
- [ ] User-Assigned Managed Identity created (`id-azurehealth-shared`)
- [ ] Reader role assigned (subscription scope)
- [ ] Monitoring Reader role assigned (subscription scope)
- [ ] Storage Blob Data Contributor role assigned (storage scope)
- [ ] Resource lock applied to shared RG
- [ ] Function App uses User-Assigned identity
- [ ] Identity info file created (`shared-identity-info.json`)
- [ ] Service Health API accessible
- [ ] Storage blob operations work
- [ ] Application Insights receiving telemetry
- [ ] Function deletion/recreation works without role reassignment

### Health Check Commands

```bash
# 1. Shared infrastructure health
./scripts/infrastructure/validate-shared-setup.ps1

# 2. Function App identity
az functionapp show \
  --name func-azurehealth-dev \
  --resource-group rg-azure-health-dev \
  --query identity

# 3. Role assignments
az role assignment list \
  --assignee $(jq -r '.principalId' scripts/infrastructure/shared-identity-info.json) \
  --all \
  --output table

# 4. Function runtime
az functionapp function show \
  --name func-azurehealth-dev \
  --resource-group rg-azure-health-dev \
  --function-name HealthCheck

# 5. Storage access
az storage blob list \
  --account-name <storage-name> \
  --container-name cache \
  --auth-mode login \
  --num-results 5
```

## Rollback Procedure

If issues occur, you can roll back to System-Assigned Managed Identity:

### Option 1: Revert Bicep Templates

```bash
# 1. Restore original main.bicep
git checkout HEAD~1 -- infrastructure/main.bicep

# 2. Restore original main.bicepparam
git checkout HEAD~1 -- infrastructure/main.bicepparam

# 3. Redeploy with System-Assigned identity
./scripts/infrastructure/deploy-bicep.ps1 -Environment dev

# 4. Reassign roles (will be done by script)
```

### Option 2: Manual Portal Configuration

1. Go to Azure Portal → Function App → Identity
2. Under "System assigned" tab, set Status to "On"
3. Click "Azure role assignments"
4. Add role assignments:
   - Reader (subscription scope)
   - Monitoring Reader (subscription scope)
   - Storage Blob Data Contributor (storage scope)

### Cleanup After Rollback

```bash
# Remove shared infrastructure (if no longer needed)
az lock delete \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared

az group delete \
  --name rg-azure-health-shared \
  --yes --no-wait

# Remove identity info file
rm scripts/infrastructure/shared-identity-info.json
```

## Troubleshooting

### Issue: "Shared resource group not found"

**Symptoms:**
```
Error: Shared resource group 'rg-azure-health-shared' not found.
```

**Solution:**
```bash
# Run shared infrastructure setup
cd scripts/infrastructure
./setup-shared-identity.ps1
```

### Issue: "Identity info file not found"

**Symptoms:**
```
Error: Identity info file not found: shared-identity-info.json
```

**Solution:**
```bash
# Regenerate identity info file
cd scripts/infrastructure

IDENTITY_JSON=$(az identity show \
  --name id-azurehealth-shared \
  --resource-group rg-azure-health-shared)

echo $IDENTITY_JSON | jq '{
  resourceGroup: "rg-azure-health-shared",
  identityName: "id-azurehealth-shared",
  principalId: .principalId,
  clientId: .clientId,
  resourceId: .id,
  location: .location,
  subscriptionId: .id | split("/")[2],
  createdDate: now | strftime("%Y-%m-%dT%H:%M:%SZ")
}' > shared-identity-info.json
```

### Issue: "Permission denied" when accessing storage

**Symptoms:**
```
BlobNotFound: The specified blob does not exist.
AuthorizationPermissionMismatch: This request is not authorized.
```

**Solution:**
```bash
# Verify role assignment
PRINCIPAL_ID=$(jq -r '.principalId' scripts/infrastructure/shared-identity-info.json)
STORAGE_NAME="<your-storage-account>"

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-azure-health-dev/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME

# Wait 1-2 minutes for propagation
sleep 120

# Test access
az functionapp restart --name func-azurehealth-dev --resource-group rg-azure-health-dev
```

### Issue: "Identity not found" in Function App

**Symptoms:**
```
The resource 'Microsoft.ManagedIdentity/userAssignedIdentities/id-azurehealth-shared' under resource group 'rg-azure-health-shared' was not found.
```

**Solution:**
```bash
# Verify identity exists
az identity show \
  --name id-azurehealth-shared \
  --resource-group rg-azure-health-shared

# If missing, recreate
./scripts/infrastructure/setup-shared-identity.ps1

# Redeploy Function App
./scripts/infrastructure/deploy-bicep.ps1 -Environment dev
```

### Issue: Lock prevents resource deletion

**Symptoms:**
```
The scope 'rg-azure-health-shared' cannot perform delete operation because following scope(s) are locked
```

**Solution:**
```bash
# Remove lock temporarily
az lock delete \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared

# Perform operation...

# Restore lock
az lock create \
  --name DoNotDelete-SharedInfrastructure \
  --resource-group rg-azure-health-shared \
  --lock-type CanNotDelete
```

### Issue: Bicep deployment fails with "managedIdentityResourceId required"

**Symptoms:**
```
Error: The following parameter(s) are missing: managedIdentityResourceId
```

**Solution:**
```bash
# Option 1: Update main.bicepparam with identity Resource ID
# See Step 2.2 above

# Option 2: Pass as deployment parameter
./deploy-bicep.ps1 -Environment dev -Parameters "managedIdentityResourceId=/subscriptions/.../id-azurehealth-shared"
```

## Migration Timeline

| Phase | Duration | Can Run in Parallel |
|-------|----------|---------------------|
| Phase 1: Create Shared Infrastructure | 5 min | No (prerequisite) |
| Phase 2: Update Bicep Templates | 10 min | Yes (code changes) |
| Phase 3: Update Deployment Script | 15 min | Yes (code changes) |
| Phase 4: Deploy Updated Infrastructure | 5 min | No (deployment) |
| Phase 5: Validate Migration | 10 min | No (verification) |
| **Total** | **45 min** | |

**Production Migration Window:** 15 minutes (Phase 4-5 only, assuming code changes tested in dev)

## Next Steps

After successful migration:

1. **Update Documentation**
   - Update `README.md` with new architecture
   - Update `DEPLOYMENT.md` with new deployment steps
   - Archive old System-Assigned MI documentation

2. **Migrate Other Environments**
   - Repeat migration for test environment
   - Repeat migration for production environment
   - Use same shared RG, different project RGs per environment

3. **Create CI/CD Pipeline**
   - Add `validate-shared-setup.ps1` as pipeline step
   - Configure GitHub Actions with federated credentials
   - Automate deployment using User-Assigned MI

4. **Extract Shared Infrastructure Repository**
   - Move setup scripts to separate repo (`rg-azure-health-shared`)
   - Version control shared infrastructure
   - Independent deployment pipeline for shared resources

## References

- [SHARED_INFRASTRUCTURE.md](./SHARED_INFRASTRUCTURE.md) - Architecture overview
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment procedures
- [BEST_PRACTICES.md](./BEST_PRACTICES.md) - Security best practices
- [Azure Managed Identities Best Practices](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/managed-identity-best-practice-recommendations)
- [Bicep User-Assigned Identity](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/scenarios-user-assigned-identity)
