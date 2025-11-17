---
version: 1.0.0
last-updated: 2025-11-17
---

# GitHub Actions Azure Setup - Complete Guide

## Overview

This guide helps you set up Azure authentication for GitHub Actions workflows using OpenID Connect (OIDC) federated credentials. The setup enables secure, automated deployments without storing secrets.

## What's Included

### Documentation

1. **[GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)** - Comprehensive setup guide
   - Detailed step-by-step instructions
   - Manual setup procedures
   - Federated credentials configuration
   - Azure permissions setup
   - Troubleshooting guide

2. **[GITHUB_ACTIONS_QUICKSTART.md](GITHUB_ACTIONS_QUICKSTART.md)** - Quick checklist
   - Prerequisites checklist
   - Quick setup steps
   - Verification procedures
   - Quick reference table

### Automation Scripts

Located in `scripts/setup/`:

1. **setup-github-actions-azure.sh** - Automated setup
   - Creates Azure AD application
   - Configures federated credentials
   - Assigns Azure permissions
   - Displays GitHub secrets configuration

2. **validate-github-actions-setup.sh** - Validation tool
   - Verifies Azure AD configuration
   - Checks federated credentials
   - Validates permissions
   - Checks GitHub secrets

3. **README.md** - Scripts documentation

## Quick Start

### Option 1: Automated Setup (Recommended)

```bash
# 1. Navigate to scripts directory
cd scripts/setup

# 2. Run the setup script
./setup-github-actions-azure.sh

# 3. Follow the prompts and add the displayed secrets to GitHub

# 4. Validate the setup
./validate-github-actions-setup.sh
```

### Option 2: Manual Setup

Follow the detailed instructions in [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md).

## Required GitHub Secrets

After running the setup, add these secrets to your GitHub repository at:
`https://github.com/stuartshay/pwsh-azure-health/settings/secrets/actions`

| Secret Name | Description |
|-------------|-------------|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

## Supported Workflows

Once configured, these workflows will work automatically:

1. **infrastructure-whatif.yml** - Preview infrastructure changes on PRs
2. **infrastructure-deploy.yml** - Deploy infrastructure (manual trigger)
3. **infrastructure-destroy.yml** - Destroy infrastructure (manual trigger)
4. **function-deploy.yml** - Deploy function code (auto on master, or manual trigger)
5. **lint-and-test.yml** - Run linting and tests on PRs

## Security Benefits

✅ **No client secrets** - Uses OIDC federated credentials
✅ **Short-lived tokens** - Tokens are valid only during workflow execution
✅ **Least privilege** - Only Contributor role, scoped appropriately
✅ **Audit trail** - All actions logged in Azure Activity Log
✅ **No credential rotation** - Federated credentials don't expire

## Testing Your Setup

1. **Test infrastructure-whatif workflow:**
   ```bash
   # Create a test branch
   git checkout -b test-github-actions

   # Make a small change to infrastructure
   echo "# Test change" >> infrastructure/README.md

   # Commit and push
   git add infrastructure/README.md
   git commit -m "Test: trigger infrastructure-whatif workflow"
   git push origin test-github-actions

   # Create a PR and check the workflow runs
   ```

2. **Check workflow logs:**
   - Go to Actions tab in GitHub
   - Click on the workflow run
   - Verify "Azure login" step succeeds
   - Check for successful authentication

3. **Validate with script:**
   ```bash
   ./scripts/setup/validate-github-actions-setup.sh
   ```

## Troubleshooting

### Common Issues

1. **"Unable to get OIDC token"**
   - Ensure federated credentials are configured for your branch/context
   - Run validation script to check credentials

2. **"Authorization failed"**
   - Verify Contributor role is assigned
   - Check role assignment scope matches your resources

3. **"Resource group not found"**
   - Create resource groups manually or use subscription-level permissions

### Get Help

- See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) troubleshooting section
- Run validation script: `./scripts/setup/validate-github-actions-setup.sh`
- Check workflow logs in GitHub Actions

## File Structure

```
docs/
├── GITHUB_ACTIONS_SETUP.md          # Comprehensive setup guide
├── GITHUB_ACTIONS_QUICKSTART.md     # Quick reference checklist
└── GITHUB_ACTIONS_SUMMARY.md        # This file

scripts/setup/
├── README.md                              # Scripts documentation
├── setup-github-actions-azure.sh          # Automated setup script
├── validate-github-actions-setup.sh       # Validation script
└── azure-github-actions-config.example.txt # Example output
```

## Next Steps

After successful setup:

1. ✅ Deploy infrastructure using the workflow
2. ✅ Configure additional secrets for CI/CD (FUNCTION_APP_NAME, etc.)
3. ✅ Set up GitHub environment protection for production
4. ✅ Test the full CI/CD pipeline

## Additional Resources

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Workload Identity Federation](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation)
- [Azure RBAC Documentation](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)

## Support

For issues or questions:
1. Check the troubleshooting sections in documentation
2. Run the validation script for diagnostics
3. Review GitHub Actions workflow logs
4. Check Azure Activity Log for permission issues

---

**Last Updated:** November 2025
**Version:** 1.0
