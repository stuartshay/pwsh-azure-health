# Azure Health Monitoring Functions (PowerShell)

Enterprise-grade Azure Functions application for monitoring Azure Service Health using PowerShell.

## Overview

This project provides a robust, production-ready solution for monitoring Azure Service Health through serverless Azure Functions. Built with enterprise best practices in mind, it includes comprehensive configuration, local development support, and extensibility for future health monitoring needs.

## Features

- **Azure Service Health Monitoring**: Retrieve and monitor service health events across Azure subscriptions
- **PowerShell Runtime**: Leverages PowerShell 7.4 for robust scripting capabilities
- **Resource Graph Integration**: Uses Azure Resource Graph for efficient querying
- **Enterprise Ready**: Structured with scalability and maintainability in mind
- **Local Development Support**: Complete setup for local testing and debugging

## Prerequisites

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
├── .vscode/                    # VS Code configuration
│   ├── extensions.json         # Recommended extensions
│   ├── launch.json            # Debug configuration
│   ├── settings.json          # Editor settings
│   └── tasks.json             # Build tasks
├── GetServiceHealth/          # Service Health function
│   ├── function.json          # Function bindings
│   └── run.ps1               # Function implementation
├── .editorconfig             # Code formatting rules
├── .funcignore              # Files to exclude from deployment
├── .gitignore               # Git ignore patterns
├── host.json                # Function app host configuration
├── local.settings.json      # Local development settings
├── profile.ps1              # PowerShell profile (cold start)
├── requirements.psd1        # PowerShell module dependencies
└── README.md               # This file
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

Copy the `local.settings.json.template` to `local.settings.json` and configure your Azure subscription:

```bash
cp local.settings.json.template local.settings.json
```

Then edit `local.settings.json` with your subscription ID:

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

**Note:** The `local.settings.json` file is excluded from source control for security. Always use the template to create your local configuration.

### 4. Install PowerShell Modules

The required PowerShell modules are defined in `requirements.psd1` and will be automatically installed by Azure Functions when running locally or in Azure. For local development, you can pre-install them:

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
func start
```

The function app will start on `http://localhost:7071`

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
2. Use F5 to start debugging
3. Set breakpoints in PowerShell files

### Code Formatting

This project uses EditorConfig for consistent formatting:
- PowerShell files: 4 spaces
- JSON files: 2 spaces
- Follow existing code style

### PowerShell Best Practices

- Use approved verbs for function names
- Include proper error handling with try/catch
- Write verbose logging for debugging
- Comment complex logic
- Use parameter validation

## Deployment

### Deploy to Azure

```bash
# Login to Azure
az login

# Create a resource group
az group create --name rg-azure-health --location eastus

# Create a storage account
az storage account create --name stazurehealthfunc --resource-group rg-azure-health --location eastus --sku Standard_LRS

# Create a Function App
az functionapp create --resource-group rg-azure-health --consumption-plan-location eastus \
  --runtime powershell --runtime-version 7.4 --functions-version 4 \
  --name func-azure-health --storage-account stazurehealthfunc

# Deploy the function
func azure functionapp publish func-azure-health
```

### Configure Application Settings

```bash
az functionapp config appsettings set --name func-azure-health \
  --resource-group rg-azure-health \
  --settings "AZURE_SUBSCRIPTION_ID=your-subscription-id"
```

### Enable Managed Identity

```bash
az functionapp identity assign --name func-azure-health --resource-group rg-azure-health
```

Grant the managed identity appropriate permissions to read Service Health data.

## Monitoring

### Application Insights

Configure Application Insights connection string in `local.settings.json` or Azure application settings:

```json
{
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=...;IngestionEndpoint=..."
}
```

### Logs

View logs in real-time:

```bash
func azure functionapp logstream func-azure-health
```

Or in Azure Portal:
- Navigate to your Function App
- Select "Log stream" or "Application Insights"

## Security

### Authentication

The function uses function-level authentication by default. The function key is required to invoke the API.

### Managed Identity

When deployed to Azure, the function uses Managed Identity to authenticate with Azure services. Ensure the managed identity has the following roles:
- Reader role on subscriptions to monitor
- Monitoring Reader role for Service Health data

### Secrets Management

- Never commit `local.settings.json` to source control
- Use Azure Key Vault for sensitive configuration
- Rotate function keys regularly

## Troubleshooting

### Common Issues

**Module not found errors:**
```powershell
# Ensure requirements.psd1 is properly configured
# Try clearing the module cache
Remove-Item -Path "$env:HOME/.azure/functions/managedDependencies" -Recurse -Force
```

**Authentication failures:**
```powershell
# Reconnect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

**Function timeout:**
- Adjust `functionTimeout` in `host.json`
- Optimize Resource Graph queries

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Resources

- [Azure Functions PowerShell Developer Guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell)
- [Azure Resource Health Documentation](https://docs.microsoft.com/en-us/azure/service-health/resource-health-overview)
- [Azure Resource Graph Documentation](https://docs.microsoft.com/en-us/azure/governance/resource-graph/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions:
- Open an issue in the GitHub repository
- Check existing issues and documentation

## Acknowledgments

Built with enterprise patterns and Azure best practices in mind.