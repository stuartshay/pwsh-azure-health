---
version: 1.0.0
last-updated: 2025-11-17
---

# Policy Testing Guide

## Overview

The `infrastructure-whatif.yml` workflow now includes **Azure Policy compliance testing** to help you identify potential policy violations **before** deploying infrastructure changes.

## What It Does

When you create a PR that modifies infrastructure files, the what-if workflow automatically:

1. **Runs Infrastructure What-If** - Shows what would change in Azure
2. **Checks Policy Compliance** - Generates policy reports for dev and prod environments
3. **Identifies Issues** - Highlights non-compliant resources and policy violations
4. **Provides Guidance** - Suggests how to create exemptions if needed
5. **Comments on PR** - Posts all findings directly to your pull request

## Workflow Triggers

The what-if workflow runs automatically on PRs that modify:
- `infrastructure/**` files
- `.github/workflows/infrastructure-*.yml` files

## What You'll See in PR Comments

### 1. Infrastructure Changes Preview
```
## Dev Environment What-If

### Y1 (Consumption Plan)
[Shows resources that would be created/modified/deleted]

### EP1 (Elastic Premium Plan)
[Shows resources that would be created/modified/deleted]
```

### 2. Policy Compliance Preview
```
## 🛡️ Policy Compliance Preview

### Dev Environment

**Policy Assignments (7):**
  - ❌ Deny App Service Plan Not EP1 SKU - NonCompliant
    • Non-compliant resources:
      - azhealth-dev-plan (Microsoft.Web/serverfarms) - eastus

  - ✅ Require CostCenter Tag - Compliant

**Policy Exemptions (2):**
  - 🛡️ Azure Health Function App Auth Exemption
    - Category: Waiver
    - Reason: Allow unauthenticated access for development testing
```

### 3. Policy Guidance
```
### 📖 Policy Guidance

**If policies show Non-Compliant:**
- Review the non-compliant resources listed above
- Check if exemptions are needed for development/testing
- Ensure deployments comply with organizational policies

**Common Policy Issues:**
- **Deny App Service Plan SKUs**: Y1 (Consumption) may be denied - use EP1 or request exemption
- **Require Tags**: Ensure all resources have required tags
- **Function App Authentication**: Development may need exemption
```

## Using Policy Testing

### Before Making Infrastructure Changes

1. **Review Current Policies**
   ```bash
   # List policy assignments
   az policy assignment list --resource-group rg-azure-health-dev

   # Check current compliance
   az policy state list --resource-group rg-azure-health-dev
   ```

2. **Make Your Changes**
   - Edit Bicep files in `infrastructure/`
   - Commit and push to a branch

3. **Create Pull Request**
   - The what-if workflow runs automatically
   - Review the policy compliance preview in PR comments

### Handling Policy Violations

If the what-if shows policy violations:

#### Option 1: Fix the Resource to Comply
Update your Bicep template to meet policy requirements:
```bicep
// Example: Use EP1 instead of Y1 to comply with SKU policy
param functionAppPlanSku string = 'EP1'  // Changed from Y1
```

#### Option 2: Request a Policy Exemption
If the violation is intentional (e.g., for development):

```bash
# Create exemption for development environment
az policy exemption create \
  --name 'dev-y1-sku-exemption' \
  --display-name 'Allow Y1 SKU for Dev Environment' \
  --policy-assignment '/subscriptions/.../policyAssignments/deny-app-service-plan' \
  --resource-group 'rg-azure-health-dev' \
  --exemption-category 'Waiver' \
  --description 'Development environment needs Y1 SKU for cost savings' \
  --expires-on '2026-12-31'
```

The exemption will appear in the next what-if run.

## Testing Different Scenarios

The what-if workflow tests **both** Y1 and EP1 SKUs for each environment, showing you:

- ✅ Which SKU would pass policy validation
- ❌ Which SKU would be blocked by policies
- 🛡️ Which exemptions are currently active

This helps you make informed decisions about:
- Which SKU to deploy
- Whether you need exemptions
- How policies differ between dev and prod

## Benefits

### Early Detection
- Find policy issues **before** deployment attempts
- No wasted time on failed deployments
- No need to troubleshoot policy denials in logs

### Better Planning
- See exactly which resources violate which policies
- Understand exemption requirements upfront
- Plan exemption requests in advance

### Documentation
- PR comments serve as policy compliance records
- Easy to review why deployments might fail
- Clear guidance for team members

## Example PR Comment

When you create a PR, you'll see a comment like:

```markdown
## 🔍 Infrastructure What-If Preview

### Dev Environment What-If

#### Y1 (Consumption Plan)
[Shows what would deploy]

#### EP1 (Elastic Premium Plan)
[Shows what would deploy]

---

## 🛡️ Policy Compliance Preview

### Dev Environment

**Policy Assignments (7):**
  - ❌ **Deny App Service Plan Not EP1 SKU** - NonCompliant
    • Non-compliant resources (1):
      - azhealth-dev-plan (Microsoft.Web/serverfarms)

**Policy Exemptions (1):**
  - 🛡️ **Dev Y1 SKU Exemption** - Waiver
    - Expires: 2026-12-31
    - Reason: Development environment cost optimization
    - Policy: deny-app-service-plan-not-ep1-sku

---

### 📖 Policy Guidance
[Guidance on handling issues]
```

## Next Steps

After reviewing the what-if and policy preview:

1. **If everything looks good** ✅
   - Approve and merge the PR
   - The deployment workflow will use the same policy checks

2. **If policies need exemptions** 🛡️
   - Create exemptions using the provided examples
   - Re-run the workflow to confirm
   - Document the exemption in PR description

3. **If changes are needed** 🔧
   - Update Bicep templates to comply with policies
   - Push updates to trigger new what-if run
   - Review the updated preview

## Related Documentation

- [Azure Policy Compliance Reporting](./API.md#policy-compliance)
- [Deployment Guide](./DEPLOYMENT.md)
- [Security & Permissions](./SECURITY_PERMISSIONS.md)
- [GitHub Actions Setup](./GITHUB_ACTIONS_SETUP.md)
