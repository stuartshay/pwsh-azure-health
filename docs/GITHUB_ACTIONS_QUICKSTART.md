---
version: 1.0.0
last-updated: 2025-11-17
---

# GitHub Actions Quick Start Guide

Use this checklist to quickly set up GitHub Actions for automated deployments.

## Prerequisites Checklist

- [ ] Azure CLI installed (`az --version`)
- [ ] Logged in to Azure (`az login`)
- [ ] Have Owner or User Access Administrator role on Azure subscription
- [ ] Have admin access to GitHub repository

## Setup Steps

### Option 1: Automated Setup (Recommended)

- [ ] Run the setup script:
  ```bash
  cd scripts/setup
  ./setup-github-actions-azure.sh
  ```

- [ ] Review the displayed configuration
- [ ] Add GitHub secrets to repository:
  - [ ] `AZURE_CLIENT_ID`
  - [ ] `AZURE_TENANT_ID`
  - [ ] `AZURE_SUBSCRIPTION_ID`

### Option 2: Manual Setup

If you prefer to set up manually, follow [docs/GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md).

## Verify Setup

- [ ] Create a test PR that modifies files in `infrastructure/`
- [ ] Check that `infrastructure-whatif.yml` workflow runs successfully
- [ ] Verify the what-if preview comment appears on the PR
- [ ] Check workflow logs for successful Azure authentication

## Deploy Infrastructure

After setup is verified:

- [ ] Go to Actions → Deploy Infrastructure
- [ ] Click "Run workflow"
- [ ] Select environment (dev or prod)
- [ ] Wait for deployment to complete
- [ ] Note the Function App name from the workflow output

## Test Function Deployment

After infrastructure is deployed, test function code deployment:

- [ ] Push changes to `src/` directory on `master` branch
- [ ] Or manually trigger "Deploy Function App" workflow from Actions tab
- [ ] Verify deployment completes successfully

## Test Full Workflow

- [ ] Push a change to `src/` on the `master` branch
- [ ] Verify the "Deploy Function App" workflow runs automatically
- [ ] Or manually trigger deployment from Actions tab
- [ ] Test the deployed function endpoint

## Troubleshooting

If you encounter issues:

1. Check [docs/GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) troubleshooting section
2. Verify all GitHub secrets are configured correctly
3. Check Azure AD federated credentials match your repository
4. Ensure service principal has Contributor role
5. Review GitHub Actions workflow logs

## Quick Reference

| Item | Value/Location |
|------|----------------|
| Setup Script | `scripts/setup/setup-github-actions-azure.sh` |
| Detailed Docs | `docs/GITHUB_ACTIONS_SETUP.md` |
| GitHub Secrets | `https://github.com/stuartshay/pwsh-azure-health/settings/secrets/actions` |
| Workflows | `.github/workflows/` |
| Infrastructure | `infrastructure/main.bicep` |

## Security Reminders

- ✅ Never commit secrets to Git
- ✅ Use OIDC federated credentials (no client secrets)
- ✅ Review Azure Activity Log for unauthorized actions
- ✅ Configure GitHub environment protection for production
- ✅ Keep `azure-github-actions-config.txt` secure

---

**Need help?** See the full documentation in [docs/GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
