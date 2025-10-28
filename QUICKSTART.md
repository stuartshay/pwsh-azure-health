# Quick Start Guide

Get up and running with Azure Health Monitoring Functions in 5 minutes!

## Prerequisites

- PowerShell 7.4+
- Azure Functions Core Tools v4
- Azure subscription

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/stuartshay/pwsh-azure-health.git
cd pwsh-azure-health
```

### 2. Install Azure Functions Core Tools

**macOS:**
```bash
brew tap azure/functions
brew install azure-functions-core-tools@4
```

**Windows:**
```powershell
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

**Linux:**
```bash
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4
```

### 3. Setup Local Configuration

```bash
# Copy the template from src/
cp src/local.settings.json.template src/local.settings.json

# Edit src/local.settings.json and add your subscription ID
# Replace "your-subscription-id-here" with your actual subscription ID
```

### 4. Authenticate with Azure

```powershell
pwsh
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

### 5. Run the Function Locally

```bash
func start --script-root src
```

You should see:
```
Azure Functions Core Tools
Core Tools Version:       4.x.xxxx
Function Runtime Version: 4.x.xxxx

Functions:
  GetServiceHealth: [GET,POST] http://localhost:7071/api/GetServiceHealth
```

### 6. Test the Function

Open a new terminal and run:

```bash
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

Or using PowerShell:
```powershell
Invoke-RestMethod -Uri "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

## Expected Response

```json
{
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "retrievedAt": "2025-10-28T17:23:45.1234567Z",
  "eventCount": 0,
  "events": []
}
```

## Common Issues

### "Module not found" error
```powershell
# Clear module cache and restart
Remove-Item -Path "$env:HOME/.azure/functions/managedDependencies" -Recurse -Force
func start --script-root src
```

### "Authentication failed" error
```powershell
# Reconnect to Azure
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

### "Port already in use" error
```bash
# Use a different port
func start --port 7072 --script-root src
```

## Next Steps

1. **Read the Documentation**
   - [Detailed Setup Guide](docs/SETUP.md)
   - [API Documentation](docs/API.md)
   - [Deployment Guide](docs/DEPLOYMENT.md)

2. **Customize the Function**
   - Modify query parameters in `src/GetServiceHealth/run.ps1`
   - Adjust time range (currently 7 days) in `src/shared/Modules/ServiceHealth.psm1`
   - Add additional filters or telemetry helpers in `src/shared/`

3. **Deploy to Azure**
   - Use the deployment script: `./scripts/deployment/deploy-to-azure.sh`
   - Or deploy via VS Code Azure Functions extension
   - See [Deployment Guide](docs/DEPLOYMENT.md) for details

4. **Add More Functions**
   - Create new function folders under `src/`
   - Share common logic via `src/shared/Modules`
   - See [Contributing Guide](CONTRIBUTING.md) for guidelines

## Development Workflow

```bash
# 1. Make changes to the code
# 2. Test locally
func start --script-root src

# 3. In another terminal, test the function
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=xxx"

# 4. Commit your changes
git add .
git commit -m "Description of changes"
git push
```

## VS Code Setup

1. Open the project in VS Code
2. Install recommended extensions when prompted
3. Press F5 to start debugging (runs `func start --script-root src`)
4. Set breakpoints in PowerShell files under `src/`
5. Test and debug

## Resources

- [Azure Functions PowerShell Developer Guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell)
- [Azure Resource Health](https://docs.microsoft.com/en-us/azure/service-health/resource-health-overview)
- [Azure Resource Graph](https://docs.microsoft.com/en-us/azure/governance/resource-graph/)

## Getting Help

- Review the [Setup Guide](docs/SETUP.md) for detailed instructions
- Check [API Documentation](docs/API.md) for endpoint details
- Open an issue on GitHub for bugs or questions

---

**Ready to deploy?** Check out the [Deployment Guide](docs/DEPLOYMENT.md)!
