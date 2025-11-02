# Azure Health Monitoring Functions (PowerShell)

[![Deploy Infrastructure](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/infrastructure-deploy.yml/badge.svg)](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/infrastructure-deploy.yml)

[![Deploy Function App](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/function-deploy.yml/badge.svg)](https://github.com/stuartshay/pwsh-azure-health/actions/workflows/function-deploy.yml)

Enterprise-grade Azure Functions application for monitoring Azure Service Health using PowerShell.

## Overview

This project provides a robust, production-ready solution for monitoring Azure Service Health through serverless Azure Functions. Built with enterprise best practices in mind, it includes comprehensive configuration, local development support, and extensibility for future health monitoring needs.

## Features

- **Azure Service Health Monitoring**: Retrieve and monitor service health events across Azure subscriptions
- **PowerShell Runtime**: Leverages PowerShell 7.4 for robust scripting capabilities
- **Resource Graph Integration**: Uses Azure Resource Graph for efficient querying
- **Enterprise Ready**: Structured with scalability and maintainability in mind
- **Local Development Support**: Complete setup for local testing and debugging
- **DevContainer Support**: Pre-configured development environment with all prerequisites
- **GitHub Copilot Custom Agent**: Specialized AI assistant for PowerShell Azure Functions development

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
- Appropriate permissions to read Service Health data
- Azure Functions resource (for deployment)
- Application Insights instance (optional, for monitoring)

## Project Structure

```
pwsh-azure-health/
├── docs/                       # Documentation (best practices, deployment, setup)
├── scripts/
│   ├── ci/                     # Continuous integration helpers (placeholder)
│   ├── deployment/             # Deployment automation scripts
│   │   └── deploy-to-azure.sh
│   └── local/                  # Local development utilities
│       └── setup-local-dev.ps1
├── src/
│   ├── GetServiceHealth/       # Service Health function implementation
│   │   ├── function.json       # Function bindings
│   │   └── run.ps1             # HTTP trigger entry point
│   ├── shared/
│   │   ├── Modules/            # Reusable PowerShell modules
│   │   │   └── ServiceHealth.psm1
│   │   └── Scripts/            # Common scripts and helpers
│   │       └── HttpHelpers.ps1
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

The required PowerShell modules are defined in `src/requirements.psd1` and will be automatically installed by Azure Functions when running locally or in Azure. For local development, you can pre-install them:

```powershell
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
Install-Module -Name Az.ResourceGraph -Repository PSGallery -Force
Install-Module -Name Az.Monitor -Repository PSGallery -Force
```

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

- **PowerShell Linting**: PSScriptAnalyzer checks for code quality and best practices
- **File Quality**: Trailing whitespace, end-of-file fixes, line ending consistency
- **Security**: GitLeaks scans for secrets, passwords, and API keys
- **YAML/JSON Validation**: Syntax checking for configuration files
- **Large File Detection**: Prevents committing files >500KB
- **Merge Conflict Detection**: Prevents committing files with conflict markers
- **Branch Protection**: Blocks direct commits to master/main branches
- **Unit Tests**: Pester tests run on pre-push

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
./scripts/pre-commit-hook.sh
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

To enable automated deployments and infrastructure management via GitHub Actions, you need to configure Azure authentication. We provide an automated setup script:

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

📖 **See [docs/GITHUB_ACTIONS_SETUP.md](docs/GITHUB_ACTIONS_SETUP.md) for detailed instructions**

### Manual Deployment

See [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for detailed deployment instructions using Azure CLI or VS Code.
