# Azure Permissions & Security Architecture

**Document Version:** 2.0
**Last Updated:** November 17, 2025
**Security Classification:** Internal

## Executive Summary

This document provides a comprehensive overview of the Azure permissions, security controls, and identity architecture for the PowerShell Azure Health Functions application. The implementation follows enterprise security best practices with a **least-privilege** security model using **User-Assigned Managed Identity** and **Azure RBAC**.

### Security Posture

✅ **Production Ready** - Implements industry-standard security controls  
✅ **Least Privilege** - Minimal permissions for required operations  
✅ **Zero Credentials** - No secrets or connection strings in code  
✅ **Identity-Based** - Leverages Azure AD Managed Identity

---

## Table of Contents

1. [Azure RBAC Role Assignments](#1-azure-rbac-role-assignments)
2. [Managed Identity Architecture](#2-managed-identity-architecture)
3. [Service-Specific Permissions](#3-service-specific-permissions)
4. [Security Controls](#4-security-controls)
5. [Deployment Procedures](#5-deployment-procedures)
6. [Monitoring & Auditing](#6-monitoring--auditing)
7. [Compliance & Governance](#7-compliance--governance)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Azure RBAC Role Assignments

### 1.1 Overview

The Function App requires **three** Azure RBAC role assignments to operate:

| Role | Scope | Purpose | Built-in Role ID |
|------|-------|---------|------------------|
| **Reader** | Subscription | Query Azure Resource Graph for Service Health events | `acdd72a7-3385-48ef-bd42-f606fba81ae7` |
| **Monitoring Reader** | Subscription | Read Application Insights and monitoring data | `43d0d8ad-25c7-4714-9337-8ba259a9fe05` |
| **Storage Blob Data Contributor** | Storage Account | Read/write cache blobs | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` |

### 1.2 Reader Role

**Configuration:** `infrastructure/modules/roleAssignments.bicep` (lines 14-27)

#### Permissions Granted

```text
Actions:
  */read                                    # Read all resources
  Microsoft.Support/*                       # Manage support tickets
  Microsoft.ResourceGraph/resources/read    # Query Resource Graph
```

#### Why This Role is Required

The **Reader** role is the minimal built-in role that provides access to **Azure Resource Graph**, which is essential for querying the `ServiceHealthResources` table. This table contains Azure Service Health events (Service Issues, Planned Maintenance, etc.).

**Query Example:**
```kusto
ServiceHealthResources
| where type =~ 'Microsoft.ResourceHealth/events'
| where properties.EventType == 'ServiceIssue'
| project id, trackingId, title, status
```

**Code Reference:** `src/shared/Modules/ServiceHealth.psm1` (function `Get-ServiceHealthEvents`)

#### What Reader Does NOT Provide

❌ No write, modify, or delete permissions  
❌ No role assignment management  
❌ No access to secrets or keys  
❌ No ability to modify resources

#### Alternative Roles Considered

| Role | Pros | Cons | Decision |
|------|------|------|----------|
| **Custom Role** with only Resource Graph read | More restrictive | Adds complexity, minimal security gain | ❌ Not recommended |
| **Monitoring Reader** alone | Simpler | Insufficient for Resource Graph | ❌ Insufficient |
| **Reader** (current) | Standard built-in role, well-documented | Broader than strictly necessary | ✅ **Recommended** |

### 1.3 Monitoring Reader Role

**Configuration:** `infrastructure/modules/roleAssignments.bicep` (lines 31-44)

#### Permissions Granted

```text
Actions:
  Microsoft.Insights/*/read                        # Read monitoring data
  Microsoft.OperationalInsights/workspaces/read    # Read Log Analytics
  Microsoft.AlertsManagement/*/read                # Read alerts
  Microsoft.Resources/deployments/read             # Read deployments
```

#### Why This Role is Required

Provides read-only access to **Application Insights**, **Log Analytics**, and monitoring data without granting broad resource access. Often paired with Reader role for comprehensive observability.

**Use Cases:**
- Query Application Insights metrics
- Read custom metrics and telemetry
- Access monitoring dashboards
- View alert rules (read-only)

#### What Monitoring Reader Does NOT Provide

❌ No write permissions to monitoring data  
❌ No resource creation or deletion  
❌ No data export capabilities  
❌ No alert rule modifications

### 1.4 Storage Blob Data Contributor Role

**Configuration:** `infrastructure/main.bicep` (lines 222-236)

#### Permissions Granted

```text
Actions:
  Microsoft.Storage/storageAccounts/blobServices/containers/read
  Microsoft.Storage/storageAccounts/blobServices/containers/write
  Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read
  Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write
  Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete
  Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action
```

#### Why This Role is Required

The function caches Service Health event data in **Azure Blob Storage** to:
- Avoid duplicate processing of events
- Track the last query timestamp
- Reduce API calls to Resource Graph
- Provide data persistence across executions

**Cache Operations:**
- **Read:** Retrieve existing cache (`servicehealth.json`)
- **Write:** Update cache with new events
- **Create:** Initialize cache container on first run

**Code Reference:** `src/shared/Scripts/BlobCache.ps1`

#### Scope Restriction

⚠️ **CRITICAL:** This role is scoped to the **storage account resource only**, not the subscription or resource group.

```bicep
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount  // ✅ Resource-level scope
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'  // Storage Blob Data Contributor
    )
    principalId: functionApp.identity.principalId
  }
}
```

#### Alternative Roles Considered

| Role | Read | Write | Delete | ACL | Decision |
|------|------|-------|--------|-----|----------|
| **Storage Blob Data Reader** | ✅ | ❌ | ❌ | ❌ | ❌ Insufficient |
| **Storage Blob Data Contributor** | ✅ | ✅ | ✅ | ❌ | ✅ **Perfect Fit** |
| **Storage Blob Data Owner** | ✅ | ✅ | ✅ | ✅ | ❌ Excessive |

### 1.5 Automatic Role Assignment

Role assignments are **automatically created** during Bicep deployment:

```bicep
module roleAssignments 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments'
  params: {
    functionAppPrincipalId: functionApp.identity.principalId
    subscriptionId: subscription().subscriptionId
  }
}
```

**Deployment Script:** `scripts/infrastructure/deploy-bicep.ps1`

---

## 2. Managed Identity Architecture

### 2.1 Identity Type

**Type:** User-Assigned Managed Identity (Shared Infrastructure)
**Configuration:** `infrastructure/main.bicep` (lines 141-147)

```bicep
// Reference to User-Assigned Managed Identity (must already exist in shared RG)
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: last(split(managedIdentityResourceId, '/'))
  scope: resourceGroup(split(managedIdentityResourceId, '/')[2], split(managedIdentityResourceId, '/')[4])
}

resource functionApp 'Microsoft.Web/sites@2025-03-01' = {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
}
```

### 2.2 Why User-Assigned?

| Feature | System-Assigned | User-Assigned | Our Choice |
|---------|----------------|---------------|------------|
| **Lifecycle** | Tied to resource | Independent | ✅ User |
| **Sharing** | Single resource | Multiple resources | ✅ User |
| **Complexity** | Low | Medium | ✅ User |
| **Use Case** | Single-purpose functions | Multi-resource scenarios | ✅ User |
| **Reusability** | Cannot reuse | Reusable across environments | ✅ User |

**Rationale:** User-Assigned Managed Identity is provisioned once in a shared resource group and referenced by multiple Function App deployments (dev, staging, prod). This provides:
- **Centralized identity management**: Single identity for all environments
- **Simplified role assignments**: Assign RBAC roles once, not per deployment
- **Better lifecycle management**: Identity persists even if Function Apps are deleted/recreated
- **Deployment flexibility**: Easier to manage federated credentials for CI/CD

**Setup Documentation:** See [`SHARED_INFRASTRUCTURE.md`](SHARED_INFRASTRUCTURE.md) for provisioning the shared managed identity.

### 2.3 Identity Authentication Flow

```
┌─────────────┐     ┌──────────────────┐     ┌───────────┐
│ Function App│────>│Managed Identity  │────>│ Azure AD  │
└─────────────┘     └──────────────────┘     └───────────┘
       │                     │                      │
       │                     │<─────Access Token────┤
       │<────Token───────────┤                      │
       │                                            │
       ▼                                            │
┌──────────────────┐                                │
│ Resource Graph   │<───────Query with Token────────┤
└──────────────────┘                                │
       │                                            │
       ▼                                            │
┌──────────────────┐                                │
│ Storage Account  │<───────Write with Token────────┘
└──────────────────┘
```

### 2.4 PowerShell Authentication

**Automatic Authentication:** `src/profile.ps1`

```powershell
# Connect using Managed Identity on cold start
if ($env:MSI_ENDPOINT) {
    Write-Information "Authenticating with Managed Identity..."
    Connect-AzAccount -Identity -WarningAction SilentlyContinue
    Write-Information "PowerShell Azure Health Functions Profile loaded."
} else {
    Write-Warning "Not running in Azure Functions environment."
}
```

**Manual Context Switch:** `src/shared/Modules/ServiceHealth.psm1`

```powershell
# Ensure correct subscription context
try {
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
} catch {
    Write-Error "Failed to set Azure context to subscription ${SubscriptionId}: $_"
    throw
}
```

### 2.5 Retrieving Principal ID

**Via Azure Portal:**
1. Navigate to Function App → Identity → System assigned
2. Copy **Object (principal) ID**

**Via Azure CLI:**
```bash
az functionapp identity show \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --query principalId -o tsv
```

**Via Bicep Output:**
```bicep
output functionAppPrincipalId string = functionApp.identity.principalId
```

---

## 3. Service-Specific Permissions

### 3.1 Azure Resource Graph

#### Required Permission

```text
Microsoft.ResourceGraph/resources/read
```

Provided by: **Reader** role at subscription scope

#### Operations Performed

| Operation | Cmdlet | Permission Required |
|-----------|--------|---------------------|
| Query Service Health events | `Search-AzGraph` | `Microsoft.ResourceGraph/resources/read` |
| Filter by subscription | `-Subscription` parameter | `Microsoft.Resources/subscriptions/read` |

#### Example Query

```powershell
$query = @"
ServiceHealthResources
| where type =~ 'Microsoft.ResourceHealth/events'
| extend eventType = tostring(properties.EventType),
         status = tostring(properties.Status),
         title = tostring(properties.Title),
         lastUpdate = todatetime(properties.LastUpdateTime)
| where eventType == 'ServiceIssue' or eventType == 'PlannedMaintenance'
| where status == 'Active' or lastUpdate >= datetime('$isoStart')
| project id, trackingId, eventType, status, title, summary, lastUpdateTime
| order by lastUpdateTime desc
"@

$results = Search-AzGraph -Query $query -Subscription $SubscriptionId
```

**Code:** `src/shared/Modules/ServiceHealth.psm1:52-80`

#### Resource Graph Tables Accessed

- **ServiceHealthResources** - Service Health events (Service Issues, Planned Maintenance, Health Advisories)

#### Resource Graph Quotas

| Limit Type | Default | Notes |
|------------|---------|-------|
| Requests per 5 seconds | 15 | Per tenant |
| Concurrent requests | 180 | Per tenant |
| Results per query | 1000 | Use pagination for more |

**Mitigation:** Function queries every 15 minutes, well below quota limits.

### 3.2 Azure Storage (Blob)

#### Required Permissions

```text
Microsoft.Storage/storageAccounts/blobServices/containers/read
Microsoft.Storage/storageAccounts/blobServices/containers/write
Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read
Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write
Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete
```

Provided by: **Storage Blob Data Contributor** role at storage account scope

#### Identity-Based Authentication

**Environment Variable:** `AzureWebJobsStorage__accountname`

```bicep
// infrastructure/main.bicep (app settings section)
{
  name: 'AzureWebJobsStorage__accountname'
  value: storageAccount.name
}
```

**PowerShell Code:**
```powershell
# src/shared/Scripts/BlobCache.ps1:21-26
$storageAccountName = $env:AzureWebJobsStorage__accountname

if ($storageAccountName) {
    # ✅ Identity-based authentication (production)
    $context = New-AzStorageContext `
        -StorageAccountName $storageAccountName `
        -UseConnectedAccount
} elseif ($connectionString) {
    # ⚠️ Fallback for local development
    $context = New-AzStorageContext -ConnectionString $connectionString
}
```

#### Storage Operations

| Operation | Function | Permission | Error Handling |
|-----------|----------|------------|----------------|
| **Get cache** | `Get-BlobCache` | Blob read | Returns `$null` if not found |
| **Update cache** | `Update-BlobCache` | Blob write | Creates container if missing |
| **List containers** | `Get-AzStorageContainer` | Container read | Validates container exists |

**Code:** `src/shared/Scripts/BlobCache.ps1`

#### Cache Schema

**Blob:** `servicehealth-cache/servicehealth.json`

```json
{
  "lastQueryTime": "2025-11-04T05:30:00.0000000Z",
  "events": [
    {
      "id": "/subscriptions/.../providers/Microsoft.ResourceHealth/events/...",
      "trackingId": "ABCD-123",
      "eventType": "ServiceIssue",
      "status": "Active",
      "title": "Azure Service Issue",
      "summary": "Description...",
      "level": "Warning",
      "impactedServices": [...],
      "lastUpdateTime": "2025-11-04T00:00:00Z"
    }
  ]
}
```

### 3.3 Application Insights

#### Authentication Method

**Connection String** (not RBAC-based for telemetry ingestion)

```bicep
// infrastructure/main.bicep:148-150
{
  name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
  value: appInsights.properties.ConnectionString
}
```

#### Why No RBAC for Application Insights?

Application Insights uses **connection strings** for telemetry **ingestion** (write-only). RBAC is used for **querying** data (read), which is covered by **Monitoring Reader** role.

| Operation | Auth Method | Permission |
|-----------|-------------|------------|
| **Write telemetry** | Connection String | N/A (write-only key) |
| **Query metrics** | RBAC | Monitoring Reader role |
| **View dashboards** | RBAC | Monitoring Reader role |

#### Operations Performed

- Custom events (`Track-Event`)
- Exception logging (`Track-Exception`)
- Performance metrics (`Track-Metric`)
- Dependency tracking (automatic)

**PowerShell Integration:** Automatic via Azure Functions runtime

---

## 4. Security Controls

### 4.1 Network Security

#### HTTPS Enforcement

```bicep
// infrastructure/main.bicep
resource functionApp 'Microsoft.Web/sites@2025-03-01' = {
  properties: {
    httpsOnly: true  // ✅ Enforce HTTPS
  }
}
```

#### TLS Version

**Minimum TLS:** 1.2

```bicep
// infrastructure/main.bicep:174
siteConfig: {
  minTlsVersion: '1.2'  // ✅ TLS 1.2 minimum
}
```

#### Storage Account Security

```bicep
// infrastructure/main.bicep:52-54
properties: {
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
  allowBlobPublicAccess: false  // ✅ No anonymous access
}
```

#### CORS Configuration

**Allowed Origins:**
```bicep
// infrastructure/main.bicep:175-183
cors: {
  allowedOrigins: [
    'https://portal.azure.com'
    'https://ms.portal.azure.com'
    'https://functions.azure.com'
  ]
  supportCredentials: false
}
```

### 4.2 Authentication & Authorization

#### Function-Level Authentication

**GetServiceHealth API:**
```json
// src/GetServiceHealth/function.json
{
  "authLevel": "function"  // ✅ Requires function key
}
```

**HealthCheck API:**
```json
// src/HealthCheck/function.json
{
  "authLevel": "anonymous"  // ⚠️ Public (health probe only)
}
```

#### Easy Auth / Microsoft Entra ID

**Configuration:** `infrastructure/main.bicep:189-207`

```bicep
resource functionAppAuthConfig 'Microsoft.Web/sites/config@2024-11-01' = {
  properties: {
    globalValidation: {
      requireAuthentication: true
      unauthenticatedClientAction: 'Return401'
      excludedPaths: [
        '/api/*'  // Allow function key authentication
      ]
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          openIdIssuer: 'https://sts.windows.net/${tenant().tenantId}/v2.0'
        }
      }
    }
  }
}
```

**Why Exclude `/api/*`?**
Allows Azure Functions to use **function keys** for API authentication instead of Azure AD tokens. This is required for timer triggers and external API calls.

### 4.3 Data Protection

#### Encryption at Rest

| Service | Encryption | Key Management |
|---------|-----------|----------------|
| **Storage Account** | AES-256 | Microsoft-managed keys |
| **Application Insights** | AES-256 | Microsoft-managed keys |
| **Function App** | AES-256 | Microsoft-managed keys |

#### Encryption in Transit

✅ **TLS 1.2** enforced on all services
✅ **HTTPS-only** for all endpoints
✅ **Secure storage connections** via HTTPS

#### No Secrets in Code

✅ **Zero hardcoded credentials**
✅ **Managed Identity** for authentication
✅ **Environment variables** for configuration
✅ **No connection strings** in source control

**Configuration:** `src/local.settings.json.template`

```json
{
  "Values": {
    "AZURE_SUBSCRIPTION_ID": "<your-subscription-id>",
    "AzureWebJobsStorage__accountname": "<storage-account-name>"
  }
}
```

### 4.4 Code Security

#### PowerShell Module Management

**Managed Dependencies:** `src/requirements.psd1`

```powershell
@{
    # Pinned to specific versions for reproducible builds
    'Az.Accounts'      = '5.3.0'
    'Az.Storage'       = '9.3.0'
    'Az.ResourceGraph' = '1.2.1'
}
```

**Dependency Management:**
- **Version pinning**: Exact versions specified to prevent breaking changes
- **Renovate automation**: Automated dependency updates via grouped pull requests
- **Development dependencies**: Additional modules in root `requirements.psd1` (11 modules total)
- **Runtime dependencies**: Minimal subset in `src/requirements.psd1` (3 modules)

**Update Process:** Dependencies are updated via Renovate bot, which creates weekly PRs with grouped module updates for review and testing before merging.

#### Error Handling

**Sensitive Data Redaction:**
```powershell
# ✅ Good: Log error message, not full exception with tokens
Write-Error "Resource Graph query failed: $($_.Exception.Message)"

# ❌ Bad: Don't log full exception (may contain tokens)
Write-Error $_.Exception
```

**Code:** `src/shared/Modules/ServiceHealth.psm1:102-119`

---

## 5. Deployment Procedures

### 5.1 Pre-Deployment Checklist

Before deploying to a new environment:

- [ ] Review role assignments in `infrastructure/modules/roleAssignments.bicep`
- [ ] Verify TLS 1.2 enforcement
- [ ] Confirm blob public access disabled
- [ ] Validate CORS configuration
- [ ] Review authentication settings (Easy Auth)
- [ ] Verify managed identity configuration
- [ ] Check Application Insights connection string

### 5.2 Deployment Command

**Prerequisites:**
1. User-Assigned Managed Identity must exist in shared resource group
2. Identity must have Reader and Monitoring Reader roles at subscription scope
3. Get the full resource ID of the managed identity

**Bicep Deployment:**
```powershell
# From scripts/infrastructure/
./deploy-bicep.ps1 -Environment dev -ManagedIdentityResourceId "/subscriptions/{subId}/resourcegroups/{rgName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{name}"
```

**What Happens:**
1. Reference existing User-Assigned Managed Identity from shared resource group
2. Deploy storage account
3. Deploy Application Insights
4. Deploy Function App with User-Assigned Managed Identity
5. Assign **Storage Blob Data Contributor** role (storage account scope only)

**Note:** Reader and Monitoring Reader roles are assigned once to the shared identity, not during each deployment. See [`SHARED_INFRASTRUCTURE.md`](SHARED_INFRASTRUCTURE.md) for setup.

### 5.3 Post-Deployment Verification

#### Verify Managed Identity

**Check Function App identity configuration:**
```bash
az functionapp identity show \
  --name azurehealth-func-dev-<suffix> \
  --resource-group rg-azure-health-dev
```

Expected:
```json
{
  "type": "UserAssigned",
  "userAssignedIdentities": {
    "/subscriptions/{subId}/.../userAssignedIdentities/{name}": {
      "clientId": "<guid>",
      "principalId": "<guid>"
    }
  }
}
```

**Get shared identity principal ID:**
```bash
az identity show \
  --name <identity-name> \
  --resource-group <shared-resource-group> \
  --query principalId -o tsv
```

#### Verify Role Assignments

**Reader Role:**
```bash
az role assignment list \
  --assignee <principal-id> \
  --role Reader \
  --scope /subscriptions/<subscription-id>
```

**Storage Blob Data Contributor:**
```bash
az role assignment list \
  --assignee <principal-id> \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-azure-health-dev/providers/Microsoft.Storage/storageAccounts/<storage-account-name>
```

#### Test Function Execution

```powershell
# Trigger timer function manually
./scripts/logging/test-logging.ps1
```

**Expected Logs:**
```
✅ INFORMATION: Authenticating with Managed Identity...
✅ INFORMATION: Retrieved X event(s) from Azure Resource Graph
✅ INFORMATION: Successfully cached X new Service Health event(s)
```

### 5.4 Troubleshooting Deployment Issues

#### "Insufficient privileges to complete the operation"

**Cause:** Deploying principal lacks `User Access Administrator` or `Owner` role.

**Solution:**
```bash
# Grant deployer role assignment permissions
az role assignment create \
  --assignee <deployer-principal-id> \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>
```

#### "Role assignment already exists"

**Cause:** Re-deploying with same principal ID.

**Solution:** This is **expected** and **harmless**. Bicep will skip existing assignments.

#### "Storage account name not available"

**Cause:** Storage account names must be globally unique.

**Solution:** Change `storageAccountNameSuffix` in `main.bicepparam`.

---

## 6. Monitoring & Auditing

### 6.1 Activity Log Monitoring

**Enable Alerts for Role Changes:**

```bicep
resource roleAssignmentAlert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'alert-role-assignment-changes'
  location: 'global'
  properties: {
    scopes: [
      subscription().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Authorization/roleAssignments/write'
        }
        {
          field: 'resourceType'
          equals: 'Microsoft.Web/sites'
        }
      ]
    }
    actions: {
      actionGroups: [
        {
          actionGroupId: securityTeamActionGroup.id
        }
      ]
    }
  }
}
```

### 6.2 Audit Log Queries

**Recent Role Assignments:**
```kusto
AzureActivity
| where OperationNameValue == "MICROSOFT.AUTHORIZATION/ROLEASSIGNMENTS/WRITE"
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, ResourceId, Properties
| order by TimeGenerated desc
```

**Failed Authentication Attempts:**
```kusto
AzureActivity
| where OperationNameValue contains "AUTHENTICATE"
| where ActivityStatusValue == "Failure"
| summarize FailureCount = count() by Caller, bin(TimeGenerated, 1h)
| where FailureCount > 5
```

### 6.3 Security Center Recommendations

**Enable Azure Defender for:**
- ✅ App Service (function apps)
- ✅ Storage
- ✅ Azure Resource Manager

**Regular Reviews:**
- Quarterly RBAC audit
- Monthly Security Center review
- Weekly Application Insights error logs

---

## 7. Compliance & Governance

### 7.1 Azure Policy Enforcement

**Recommended Policies:**

| Policy | Effect | Scope |
|--------|--------|-------|
| **Require HTTPS for function apps** | Deny | Subscription |
| **Require TLS 1.2 minimum** | Audit | Subscription |
| **Block public blob access** | Deny | Storage Account |
| **Require managed identity** | Audit | Function Apps |
| **Require diagnostic logging** | DeployIfNotExists | All resources |

**Implementation:**
```bash
az policy assignment create \
  --name "require-function-https" \
  --policy "6d555dd1-86f2-4f1c-8ed7-5abae7c6cbab" \
  --scope /subscriptions/<subscription-id>
```

### 7.2 Exemptions

**Policy Exemption for Easy Auth:**

Some Azure Policies may flag Easy Auth with excluded paths as non-compliant. Create exemption:

```bash
# See: scripts/infrastructure/create-policy-exemption.ps1
./scripts/infrastructure/create-policy-exemption.ps1 -Environment dev
```

### 7.3 Compliance Frameworks

This architecture supports compliance with:

- ✅ **NIST 800-53** - AC-2 (Account Management), AC-6 (Least Privilege)
- ✅ **CIS Azure Foundations** - Section 8 (AppService)
- ✅ **ISO 27001** - A.9.2.3 (Management of privileged access rights)
- ✅ **SOC 2** - CC6.3 (Logical and physical access controls)

---

## 8. Troubleshooting

### 8.1 Permission Errors

#### "Operation returned an invalid status code 'Forbidden'"

**Symptom:** Resource Graph query fails with 403 Forbidden.

**Diagnosis:**
```bash
# Check if Reader role is assigned
az role assignment list \
  --assignee <principal-id> \
  --role Reader \
  --query "[?scope=='/subscriptions/<subscription-id>']"
```

**Resolution:**
```bash
# Assign Reader role manually
az role assignment create \
  --assignee <principal-id> \
  --role Reader \
  --scope /subscriptions/<subscription-id>
```

#### "AzureWebJobsStorage connection string is not configured"

**Symptom:** Storage access fails with connection string error.

**Diagnosis:**
```bash
# Check if identity-based auth is configured
az functionapp config appsettings list \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --query "[?name=='AzureWebJobsStorage__accountname'].value" -o tsv
```

**Resolution:**
```bash
# Set storage account name for identity-based auth
az functionapp config appsettings set \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --settings AzureWebJobsStorage__accountname=<storage-account-name>
```

### 8.2 Authentication Errors

#### "ManagedIdentityCredential authentication failed"

**Symptom:** Function fails to authenticate with User-Assigned Managed Identity.

**Diagnosis:**
```bash
# Verify User-Assigned identity is configured
az functionapp identity show \
  --name <function-app-name> \
  --resource-group <resource-group>
```

Expected:
```json
{
  "type": "UserAssigned",
  "userAssignedIdentities": {
    "/subscriptions/{subId}/.../userAssignedIdentities/{name}": {
      "clientId": "<guid>",
      "principalId": "<guid>"
    }
  }
}
```

**Resolution:**
```bash
# Assign user-assigned identity to function app
az functionapp identity assign \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --identities "/subscriptions/{subId}/resourcegroups/{rgName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{name}"
```

#### "The credentials in ServicePrincipalSecret are invalid"

**Symptom:** PowerShell `Connect-AzAccount -Identity` fails.

**Diagnosis:** Check environment variables in function app:
```bash
az functionapp config appsettings list \
  --name <function-app-name> \
  --resource-group <resource-group> \
  --query "[?name=='MSI_ENDPOINT' || name=='MSI_SECRET']"
```

**Resolution:** Restart function app to refresh MSI endpoint:
```bash
az functionapp restart \
  --name <function-app-name> \
  --resource-group <resource-group>
```

### 8.3 Query Errors

#### "Resource Graph query failed: Operation returned an invalid status code 'BadRequest'"

**Symptom:** Search-AzGraph returns 400 BadRequest.

**Diagnosis:** Check query syntax in `src/shared/Modules/ServiceHealth.psm1`.

**Common Causes:**
- Case-sensitive property names (use `tostring()` conversions)
- Incorrect table name (must be `ServiceHealthResources`)
- Invalid KQL syntax

**Resolution:** Validate query locally:
```bash
az graph query -q "ServiceHealthResources | where type =~ 'Microsoft.ResourceHealth/events' | take 1"
```

---

## Appendix A: Permission Matrix

### Complete Permission Requirements

| Service | Operation | Permission | Provided By |
|---------|-----------|------------|-------------|
| **Resource Graph** | Query ServiceHealthResources | `Microsoft.ResourceGraph/resources/read` | Reader |
| **Resource Graph** | Read subscription metadata | `Microsoft.Resources/subscriptions/read` | Reader |
| **Storage** | List containers | `Microsoft.Storage/.../containers/read` | Storage Blob Data Contributor |
| **Storage** | Create container | `Microsoft.Storage/.../containers/write` | Storage Blob Data Contributor |
| **Storage** | Read blob | `Microsoft.Storage/.../blobs/read` | Storage Blob Data Contributor |
| **Storage** | Write blob | `Microsoft.Storage/.../blobs/write` | Storage Blob Data Contributor |
| **Storage** | Delete blob | `Microsoft.Storage/.../blobs/delete` | Storage Blob Data Contributor |
| **Monitoring** | Read Application Insights | `Microsoft.Insights/components/read` | Monitoring Reader |
| **Monitoring** | Query metrics | `Microsoft.Insights/components/query/action` | Monitoring Reader |
| **Monitoring** | Write telemetry | N/A (connection string) | N/A |

---

## Appendix B: Reference Links

### Microsoft Documentation

- [Azure RBAC built-in roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- [Managed identities for Azure resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
- [Azure Resource Graph](https://learn.microsoft.com/azure/governance/resource-graph/overview)
- [Storage Blob Data roles](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
- [Function app security](https://learn.microsoft.com/azure/azure-functions/security-concepts)

### Code References

| File | Description |
|------|-------------|
| `infrastructure/main.bicep` | Main infrastructure template |
| `infrastructure/modules/roleAssignments.bicep` | RBAC role assignments |
| `src/profile.ps1` | Managed Identity authentication |
| `src/shared/Scripts/BlobCache.ps1` | Identity-based storage access |
| `src/shared/Modules/ServiceHealth.psm1` | Resource Graph queries |

---

## Document Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | 2025-11-17 | System | Updated for User-Assigned Managed Identity architecture, pinned module versions, Renovate automation, latest Bicep API versions (Storage: 2025-06-01, Web: 2025-03-01, ManagedIdentity: 2024-11-30) |
| 1.0 | 2025-11-04 | System | Initial comprehensive security documentation |

---

**Classification:** Internal
**Owner:** Platform Engineering Team
**Review Cycle:** Quarterly
**Next Review:** 2026-02-04
