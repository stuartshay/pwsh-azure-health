# Azure Health Monitoring Functions (PowerShell)

[![Deploy Infrastructure](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/infrastructure-deploy.yml/badge.svg)](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/infrastructure-deploy.yml)

[![Deploy Function App](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/function-deploy.yml/badge.svg)](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/function-deploy.yml)

Enterprise-grade Azure Functions application for monitoring Azure Service Health using PowerShell.

## Overview

This project provides a robust, production-ready solution for monitoring Azure Service Health through serverless Azure Functions. Built with enterprise best practices in mind, it includes comprehensive configuration, local development support, and extensibility for future health monitoring needs.

## 🔐 Security & Permissions

This application uses **User-Assigned Managed Identity** with **least-privilege RBAC** roles for secure, credential-free access to Azure resources. The managed identity is provisioned in a shared resource group and referenced during deployment.

### Required Azure RBAC Roles

| Role | Scope | Purpose |
|------|-------|---------|
| **Reader** | Subscription | Query Azure Resource Graph for Service Health events |
| **Monitoring Reader** | Subscription | Read Application Insights and monitoring data |
| **Storage Blob Data Contributor** | Storage Account | Read/write cache data (scoped to storage account only) |

### Security Features

- ✅ **Zero Credentials in Code** - Uses Managed Identity for all Azure authentication
- ✅ **Identity-Based Storage Access** - No connection strings, token-based blob access
- ✅ **Least Privilege Model** - Minimal permissions required for operations
- ✅ **HTTPS/TLS 1.2 Enforced** - All endpoints require secure connections
- ✅ **No Public Blob Access** - Storage account hardened with private containers
- ✅ **Enterprise Compliance** - Supports NIST 800-53, CIS, ISO 27001, SOC 2

**📖 Complete Security Documentation:** See [**`docs/SECURITY_PERMISSIONS.md`**](docs/SECURITY_PERMISSIONS.md) for:
- Detailed role assignment justifications
- Managed Identity architecture and authentication flows
- Service-specific permission requirements
- Deployment verification procedures
- Troubleshooting permission issues
- Compliance and governance guidance

## Features

- **Azure Service Health Monitoring**: Retrieve and monitor service health events across Azure subscriptions
- **PowerShell Runtime**: Leverages PowerShell 7.4 for robust scripting capabilities
- **Resource Graph Integration**: Uses Azure Resource Graph for efficient querying
- **Enterprise Ready**: Structured with scalability and maintainability in mind
- **Local Development Support**: Complete setup for local testing and debugging
- **DevContainer Support**: Pre-configured development environment with all prerequisites
- **Infrastructure as Code**: Provision Azure resources with repeatable Bicep templates
- **Cost Estimation & Analysis**: Automated cost estimation before deployment and actual cost tracking after deployment
- **GitHub Copilot Custom Agent**: Specialized AI assistant for PowerShell Azure Functions development

## Infrastructure as Code (Bicep)

All Azure resources required by the function app are defined in declarative Bicep templates under `infrastructure/`. The primary entry point is `infrastructure/main.bicep`, which composes reusable modules to deploy the Function App, storage, Application Insights, and required RBAC assignments.

You can deploy the infra stack with the provided PowerShell helper:

```powershell
./scripts/infrastructure/deploy-bicep.ps1
```

Or run an Azure CLI deployment directly:

```bash
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file infrastructure/main.bicep \
  --parameters environment=dev \
  --parameters managedIdentityResourceId="/subscriptions/{subId}/resourcegroups/{rgName}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/{name}"
```

**Note:** The `managedIdentityResourceId` parameter is required and must reference a pre-existing User-Assigned Managed Identity. See [`docs/SHARED_INFRASTRUCTURE.md`](docs/SHARED_INFRASTRUCTURE.md) for setup instructions.

📖 **See [`infrastructure/README.md`](infrastructure/README.md) for module details, parameters, and additional deployment options.**

## Quick Start with DevContainer

The fastest way to get started is using the pre-configured DevContainer:

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop) and [VS Code Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open this repository in VS Code
3. Click "Reopen in Container" when prompted (or use Command Palette: "Dev Containers: Reopen in Container")
4. Wait for the container to build (first time only)
5. Authenticate with Azure: `az login`
6. Update `src/local.settings.json` with your subscription ID
7. Start the function: `func start --script-root src`

All prerequisites (PowerShell 7.4, Azure Functions Core Tools, .NET 8, Azure CLI, and PowerShell modules) are automatically installed! See [`.devcontainer/README.md`](.devcontainer/README.md) for details.

## Prerequisites

> **💡 Using DevContainer?** If you're using the DevContainer, all required tools are pre-installed. Skip to the [Quick Start with DevContainer](#quick-start-with-devcontainer) section above.

### Required Tools

- [PowerShell 7.4](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) or later
- [Azure Functions Core Tools v4](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) or later
- [Visual Studio Code](https://code.visualstudio.com/) (recommended)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for deployment)

### Azure Requirements

- Azure subscription
- **User-Assigned Managed Identity** in a shared resource group (see [`docs/SHARED_INFRASTRUCTURE.md`](docs/SHARED_INFRASTRUCTURE.md))
- **Required RBAC roles** (automatically assigned during Bicep deployment):
  - **Reader** at subscription scope
  - **Monitoring Reader** at subscription scope
  - **Storage Blob Data Contributor** at storage account scope
- Azure Functions resource (for deployment)
- Application Insights instance (for monitoring)

> **📖 See [docs/SECURITY_PERMISSIONS.md](docs/SECURITY_PERMISSIONS.md)** for detailed permission requirements, security controls, and deployment verification procedures.
>
> **📖 See [docs/SHARED_INFRASTRUCTURE.md](docs/SHARED_INFRASTRUCTURE.md)** for setting up the shared User-Assigned Managed Identity.

## Project Structure

```
pwsh-azure-health/
├── docs/                       # Documentation (best practices, deployment, setup)
├── infrastructure/             # Bicep IaC templates and modules
│   ├── main.bicep              # Entry point template
│   ├── main.bicepparam         # Default parameter file
│   └── modules/                # Reusable Bicep modules
├── scripts/
│   ├── ci/                     # Continuous integration helpers
│   ├── deployment/             # Deployment automation scripts
│   ├── infrastructure/         # Infrastructure deployment helpers
│   ├── local/                  # Local development utilities
│   ├── logging/                # Logging and monitoring scripts
│   └── setup/                  # GitHub Actions/OIDC bootstrap scripts
├── src/
│   ├── GetServiceHealth/       # HTTP-triggered Service Health API
│   ├── GetServiceHealthTimer/  # Timer-triggered Service Health polling
│   ├── HealthCheck/            # Lightweight health probe endpoint
│   ├── shared/
│   │   ├── Modules/            # Reusable PowerShell modules (ServiceHealth)
│   │   └── Scripts/            # Common scripts and helpers (HTTP utilities)
│   ├── host.json               # Function app host configuration
│   ├── local.settings.json     # Local development settings (ignored by Git)
│   ├── local.settings.json.template
│   ├── profile.ps1             # PowerShell profile (executed on cold start)
│   └── requirements.psd1       # PowerShell module dependencies
├── tests/
│   └── unit/
│       └── ServiceHealth.Tests.ps1
└── README.md
```

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/stuartshay/pwsh-azure-health.git
cd pwsh-azure-health
```

### 2. Install Azure Functions Core Tools

**macOS (using Homebrew):**
```bash
brew tap azure/functions
brew install azure-functions-core-tools@4
```

**Windows (using npm):**
```powershell
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

**Linux (Ubuntu/Debian):**
```bash
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4
```

### 3. Configure Local Settings

Copy the template into the `src` directory and configure your Azure subscription:

```bash
cp src/local.settings.json.template src/local.settings.json
```

Then edit `src/local.settings.json` with your subscription ID:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "powershell",
    "FUNCTIONS_WORKER_RUNTIME_VERSION": "7.4",
    "AZURE_SUBSCRIPTION_ID": "your-subscription-id-here",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": ""
  }
}
```

**Note:** The `src/local.settings.json` file is excluded from source control for security. Always use the template to create your local configuration.

### 4. Install PowerShell Modules

The required PowerShell modules are defined in `src/requirements.psd1` (runtime) and `requirements.psd1` (development) with pinned versions for reproducible builds:

**Runtime modules (automatically installed by Azure Functions):**
- Az.Accounts: 5.3.0
- Az.Storage: 9.3.0
- Az.ResourceGraph: 1.2.1

For local development, install all modules:

```powershell
# Installs all pinned modules from root requirements.psd1
./scripts/local/install-dev-tools.sh
```

**Dependency management:** This project uses [Renovate](https://docs.renovatebot.com/) to automatically keep PowerShell modules and Azure Bicep API versions up-to-date with grouped pull requests.

### 5. Authenticate with Azure

```powershell
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

## Running Locally

### Start the Function App

```bash
func start --script-root src
```

The function app will start on `http://localhost:7071`.

### Test the Function

**Using curl:**
```bash
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

**Using PowerShell:**
```powershell
Invoke-RestMethod -Uri "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

**Using POST with body:**
```bash
curl -X POST http://localhost:7071/api/GetServiceHealth \
  -H "Content-Type: application/json" \
  -d '{"SubscriptionId": "your-subscription-id"}'
```

## API Reference

### GetServiceHealth

Retrieves Azure Service Health events for a specified subscription.

**Endpoint:** `GET|POST /api/GetServiceHealth`

**Parameters:**
- `SubscriptionId` (optional): Azure subscription ID. Can be provided via query string, request body, or `AZURE_SUBSCRIPTION_ID` environment variable.

**Response:**
```json
{
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "retrievedAt": "2025-10-28T17:23:00.000Z",
  "eventCount": 2,
  "events": [
    {
      "id": "/subscriptions/.../events/...",
      "eventType": "ServiceIssue",
      "status": "Active",
      "title": "Service Issue Title",
      "summary": "Description of the issue",
      "level": "Warning",
      "impactedServices": [...],
      "lastUpdateTime": "2025-10-28T10:00:00Z"
    }
  ]
}
```

### GetHealthDashboard

Provides comprehensive analytics and statistics for cached Azure Service Health events. This endpoint always returns meaningful data, even when Azure has no active service health issues, making it ideal for monitoring dashboards and trend analysis.

**Endpoint:** `GET /api/GetHealthDashboard`

**Query Parameters:**
- `topN` (optional, default: 5): Number of top affected services and regions to return

**Example Request:**
```bash
curl "https://your-function-app.azurewebsites.net/api/GetHealthDashboard?code=your-function-key"

# With topN parameter
curl "https://your-function-app.azurewebsites.net/api/GetHealthDashboard?code=your-function-key&topN=10"
```

**Response:**
```json
{
  "systemStatus": {
    "apiVersion": "1.0.0",
    "cacheLastUpdated": "2025-11-04T05:37:06Z",
    "cacheAge": "15 minutes",
    "nextUpdate": "2025-11-04T05:52:06Z",
    "dataHealth": "Healthy"
  },
  "statistics": {
    "totalEventsInCache": 5,
    "activeIssues": 2,
    "eventsByType": [
      {"type": "ServiceIssue", "count": 3},
      {"type": "PlannedMaintenance", "count": 2}
    ],
    "eventsByStatus": [
      {"status": "Active", "count": 2},
      {"status": "Resolved", "count": 3}
    ],
    "eventsByLevel": [
      {"level": "Critical", "count": 1},
      {"level": "Warning", "count": 2},
      {"level": "Informational", "count": 2}
    ],
    "dateRange": {
      "oldestEvent": "2025-10-15T08:30:00Z",
      "newestEvent": "2025-11-04T04:15:00Z"
    }
  },
  "topAffected": {
    "services": [
      {"service": "Azure App Service", "count": 3},
      {"service": "Azure Storage", "count": 2},
      {"service": "Azure SQL Database", "count": 1}
    ],
    "regions": [
      {"region": "East US", "count": 4},
      {"region": "West Europe", "count": 2},
      {"region": "Global", "count": 1}
    ]
  },
  "trends": {
    "last24Hours": 2,
    "last7Days": 4,
    "last30Days": 5
  }
}
```

**Dashboard Features:**
- **System Status**: Cache health, age, and next update time
- **Statistics**: Total events, active issues, events grouped by type/status/level
- **Top Affected**: Most frequently impacted services and Azure regions
- **Historical Trends**: Event counts over 24 hours, 7 days, and 30 days
- **Data Health Indicator**: Shows "Healthy" if cache is fresh (<20 min), "Stale" otherwise

**Use Cases:**
- Building monitoring dashboards that need consistent data
- Analyzing service health trends over time
- Identifying most frequently affected Azure services/regions
- Monitoring cache freshness and system health
- Creating reports even when no active issues exist

**Testing Locally:**

Use the included test script to validate dashboard calculations locally:

```bash
# Basic dashboard
./scripts/health/test-health-dashboard.ps1

# Detailed view
./scripts/health/test-health-dashboard.ps1 -Detailed

# JSON output for automation
./scripts/health/test-health-dashboard.ps1 -Json

# Custom top N (services/regions)
./scripts/health/test-health-dashboard.ps1 -TopN 10

# Test against production
./scripts/health/test-health-dashboard.ps1 -Environment prod
```

## Development

### VS Code Setup

1. Install recommended extensions when prompted
2. Use F5 to start debugging (`func start --script-root src`)
3. Set breakpoints in PowerShell files

### Code Formatting

This project uses EditorConfig for consistent formatting:
- PowerShell files: 4 spaces

### Code Quality and Pre-Commit Hooks

This project uses [pre-commit](https://pre-commit.com/) framework to enforce code quality standards. All commits are automatically validated for:

- **Bicep Validation**: Linting and build validation for Infrastructure as Code
- **PowerShell Linting**: PSScriptAnalyzer checks for code quality and best practices
- **File Quality**: Trailing whitespace, end-of-file fixes, line ending consistency
- **Security**: GitLeaks scans for secrets, passwords, and API keys
- **YAML/JSON Validation**: Syntax checking for configuration files
- **Large File Detection**: Prevents committing files >500KB
- **Merge Conflict Detection**: Prevents committing files with conflict markers
- **Branch Protection**: Blocks direct commits to master/main branches
- **Unit Tests**: Pester tests run on pre-push
- **BATS Tests**: 143 workflow tests for deployment scripts

📖 **See [docs/PRE_COMMIT.md](docs/PRE_COMMIT.md) for complete documentation**

**Quick Start:**

If using DevContainer, pre-commit is automatically installed. Otherwise:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install
pre-commit install --hook-type pre-push

# Run manually on all files
pre-commit run --all-files
```

**Skip hooks for a specific commit (use sparingly):**
```bash
git commit --no-verify
```

### Testing

Pester tests are located under the `tests/` directory. Run them with:

```powershell
Invoke-Pester -Script tests/unit
```

**Running all quality checks locally:**

```bash
# Run PSScriptAnalyzer
pwsh -Command "Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./.PSScriptAnalyzerSettings.psd1"

# Run Pester tests
pwsh -Command "Invoke-Pester -Path ./tests/unit -Output Detailed"

# Run pre-commit checks manually
pre-commit run --all-files
```

### GitHub Copilot Custom Agent

This project includes a custom GitHub Copilot agent (`powershell-azure-expert`) specialized for PowerShell Azure Functions development.

**To use the custom agent:**

In GitHub Copilot Chat (VS Code, Codespaces):
```
@powershell-azure-expert help me add a new Azure Function
```

When assigning Copilot to an issue:
1. Click "Assign Copilot to issue"
2. Select `powershell-azure-expert` from the "Custom agent" dropdown
3. The agent will use project-specific knowledge and best practices

For more details, see [`.github/agents/README.md`](.github/agents/README.md).

## Deployment

### GitHub Actions Setup

To enable automated deployments and infrastructure management via GitHub Actions, you need to configure Azure authentication and GitHub environments. We provide an automated setup script:

```bash
# Run the setup script
./scripts/setup/setup-github-actions-azure.sh

# Or with custom options
./scripts/setup/setup-github-actions-azure.sh --scope resourcegroup
```

The script will:
- Create Azure AD application with federated credentials
- Configure OIDC authentication for GitHub Actions
- Assign necessary Azure permissions
- Display GitHub secrets that need to be added

**GitHub Environments:** This project uses separate `dev` and `prod` environments with environment-specific variables:
- `MANAGED_IDENTITY_RESOURCE_ID`: Full resource path to User-Assigned Managed Identity
- Environment protection rules (optional for prod)

**Validation:** Use `./scripts/setup/validate-github-actions-setup.sh` to verify complete setup (17 checks).

📖 **See [docs/GITHUB_ACTIONS_SETUP.md](docs/GITHUB_ACTIONS_SETUP.md) for detailed instructions**

### Cost Estimation & Analysis

The infrastructure deployment workflow automatically:
- **Pre-deployment:** Estimates monthly costs using ACE (Azure Cost Estimator) from Bicep templates
- **Post-deployment:** Analyzes actual costs using azure-cost-cli from Azure Cost Management API
- **Summary report:** Displays comprehensive cost comparison in GitHub Actions step summary

📖 **See [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md) for complete cost estimation documentation**

### Manual Deployment

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for detailed deployment instructions using Azure CLI or VS Code.
