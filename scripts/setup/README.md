# Setup Scripts

This directory contains automated setup scripts for configuring the Azure Health Monitoring Functions project.

## Available Scripts

### setup-github-actions-azure.sh

**Purpose:** Automated setup of Azure AD application and GitHub Actions OIDC authentication

Automates the configuration of Azure AD application and federated credentials for GitHub Actions OIDC authentication.

**Prerequisites:**
- Azure CLI installed and authenticated (`az login`)
- Appropriate Azure permissions (Owner or User Access Administrator role)
- GitHub repository access

**Usage:**

```bash
# Basic usage with defaults
./setup-github-actions-azure.sh

# Specify custom options
./setup-github-actions-azure.sh --org myorg --repo myrepo --scope resourcegroup

# Show help
./setup-github-actions-azure.sh --help
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --org` | GitHub organization | `stuartshay` |
| `-r, --repo` | GitHub repository | `pwsh-azure-health` |
| `-a, --app` | Azure AD app name | `github-pwsh-azure-health` |
| `-s, --scope` | Permission scope: `subscription` or `resourcegroup` | `subscription` |
| `-h, --help` | Display help message | - |

**What it does:**

1. ✅ Creates Azure AD application for GitHub Actions
2. ✅ Creates service principal
3. ✅ Configures federated credentials for:
   - `master` branch
   - `develop` branch
   - Pull requests
   - `dev` environment
   - `prod` environment
4. ✅ Assigns Contributor role (subscription or resource group level)
5. ✅ Displays GitHub secrets configuration
6. ✅ Optionally configures GitHub secrets automatically (if GitHub CLI is installed)
7. ✅ Saves configuration to `azure-github-actions-config.txt`

**Example output:**

```
========================================
Setup Complete!
========================================

✅ Azure AD application configured successfully
✅ Federated credentials created for GitHub Actions
✅ Azure permissions assigned

ℹ️  Next steps:
  1. Add the GitHub secrets shown above to your repository
  2. Test the setup by creating a PR that modifies infrastructure files
  3. Check the GitHub Actions workflow logs to verify authentication

ℹ️  For more information, see docs/GITHUB_ACTIONS_SETUP.md

✅ Configuration saved to azure-github-actions-config.txt
```

### validate-github-actions-setup.sh

**Purpose:** Validates that Azure AD application and GitHub secrets are configured correctly

Automates the configuration of Azure AD application and federated credentials for GitHub Actions OIDC authentication.

**Prerequisites:**
- Azure CLI installed and authenticated
- GitHub CLI installed (optional, for checking secrets)

**Usage:**

```bash
# Basic validation
./validate-github-actions-setup.sh

# Specify custom options
./validate-github-actions-setup.sh --org myorg --repo myrepo

# Show help
./validate-github-actions-setup.sh --help
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-o, --org` | GitHub organization | `stuartshay` |
| `-r, --repo` | GitHub repository | `pwsh-azure-health` |
| `-a, --app` | Azure AD app name | `github-pwsh-azure-health` |
| `-h, --help` | Display help message | - |

**What it checks:**

1. ✅ Prerequisites (Azure CLI, authentication)
2. ✅ Azure AD application exists
3. ✅ Service principal exists
4. ✅ Federated credentials for all required contexts
5. ✅ Azure role assignments (Contributor role)
6. ✅ GitHub secrets configuration (if GitHub CLI available)
7. ✅ GitHub environments (optional)

**Example output:**

```
========================================
Validation Summary
========================================

Total Checks: 15
Passed:  14
Failed:  0
Warnings: 1

✅ Validation passed! GitHub Actions should work correctly.

ℹ️  Next steps:
  1. Test by creating a PR that modifies infrastructure files
  2. Check that the infrastructure-whatif.yml workflow runs
  3. Verify Azure login succeeds in the workflow logs
```

## Additional Resources

For detailed documentation on the setup process, including manual steps and troubleshooting:

- [GitHub Actions Setup Guide](../../docs/GITHUB_ACTIONS_SETUP.md)
- [Deployment Guide](../../docs/DEPLOYMENT.md)

## Security Notes

- ✅ Scripts use OIDC federated credentials (no client secrets stored)
- ✅ Follows least privilege principle
- ✅ All actions are logged in Azure Activity Log
- ✅ Configuration files contain sensitive information - keep secure and don't commit to Git

## Troubleshooting

### Azure CLI not installed

```bash
# Install Azure CLI (macOS)
brew install azure-cli

# Install Azure CLI (Ubuntu/Debian)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure CLI (Windows)
# Download from: https://aka.ms/installazurecliwindows
```

### Not logged in to Azure

```bash
az login
az account set --subscription <subscription-id>
```

### Permission denied error

```bash
chmod +x setup-github-actions-azure.sh
```

### Insufficient Azure permissions

Contact your Azure subscription administrator to grant you:
- Owner role, or
- User Access Administrator + Contributor roles

## Contributing

When adding new setup scripts:

1. Follow the existing script structure and style
2. Include comprehensive help text in the script header
3. Add error handling and validation
4. Update this README with the new script documentation
5. Make the script executable: `chmod +x script-name.sh`
