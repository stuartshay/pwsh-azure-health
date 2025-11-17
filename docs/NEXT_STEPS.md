# Local Development Setup - Quick Start

> **Note**: This document provides quick setup instructions for local development. For detailed information, see:
> - [docs/LOCAL_STORAGE.md](LOCAL_STORAGE.md) - Azurite setup and storage emulation
> - [docs/SETUP.md](SETUP.md) - Complete development environment setup
> - [docs/DEPLOYMENT.md](DEPLOYMENT.md) - Deployment instructions

## Current DevContainer Features ✅

The DevContainer automatically includes:

- ✅ **Azurite Extension**: VS Code extension handles Azure Storage emulation
- ✅ **Port Forwarding**: Ports 10000-10002 configured for Blob, Queue, Table services
- ✅ **Azure CLI**: Pre-installed for Azure management
- ✅ **Azure Developer CLI (azd)**: Added as a DevContainer feature
- ✅ **PowerShell 7.4**: For function development
- ✅ **Azure Functions Core Tools**: For local function testing
- ✅ **Pre-commit Hooks**: Automated code quality checks

## Quick Setup Steps 🚀

### 1. Start Azurite (Storage Emulator)

Azurite is managed via VS Code extension - no manual installation needed!

**Start Azurite:**
- Click "Azurite" in VS Code status bar, OR
- Command Palette (F1) → "Azurite: Start"

**Verify:**
```bash
# Test blob endpoint
curl http://127.0.0.1:10000/devstoreaccount1?comp=list
```

### 2. Azure Authentication

```bash
# Login to Azure
az login

# Set default subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify
az account show
```

### 3. Configure Local Settings

Edit `src/local.settings.json`:

```json
{
  "Values": {
    "AZURE_SUBSCRIPTION_ID": "YOUR_SUBSCRIPTION_ID_HERE",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "powershell"
  }
}
```

> **Note**: `local.settings.json` is in `.gitignore` and won't be committed.

### 4. Start and Test Functions

```bash
cd src
func start
```

Test endpoints:
```bash
# Health check
curl "http://localhost:7071/api/HealthCheck"

# Service Health
curl "http://localhost:7071/api/GetServiceHealth?subscriptionId=YOUR_SUBSCRIPTION_ID"
```

## Verification Checklist 📋

- [ ] Azurite running (use VS Code extension)
- [ ] Azure CLI authenticated (`az account show` works)
- [ ] `local.settings.json` configured with subscription ID
- [ ] Functions host starts: `cd src && func start`
- [ ] HealthCheck endpoint responds: `curl http://localhost:7071/api/HealthCheck`
- [ ] GetServiceHealth returns data

## Troubleshooting 🔍

### Azurite Issues

- **Start via VS Code**: Click "Azurite" in status bar or Command Palette → "Azurite: Start"
- **Check ports**: VS Code PORTS tab should show 10000, 10001, 10002
- **Alternative**: Use `scripts/local/start-azurite.sh` (if npm azurite is installed)

### Azure Authentication

```bash
# Clear and re-authenticate
az account clear
az login --use-device-code  # If browser doesn't work

# Verify Reader role (needed for Service Health)
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

### Function Errors

1. **Connection errors**: Ensure Azurite is running and ports are forwarded
2. **PowerShell errors**: Check you're using PowerShell 7.4+ (`pwsh --version`)
3. **Module errors**: Functions host installs Az modules automatically from `requirements.psd1`

## Documentation References 📚

- [LOCAL_STORAGE.md](LOCAL_STORAGE.md) - Azurite and storage emulation details
- [SETUP.md](SETUP.md) - Complete development environment setup
- [DEPLOYMENT.md](DEPLOYMENT.md) - Azure deployment guide
- [API.md](API.md) - API endpoints documentation
- [PRE_COMMIT.md](PRE_COMMIT.md) - Pre-commit hooks reference
- [COST_ESTIMATION.md](COST_ESTIMATION.md) - Azure cost estimation guide

## Next Steps 🚀

Once local development is working:

1. **Deploy to Azure**: See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment options
2. **Set up CI/CD**: Configure GitHub Actions (see [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md))
3. **Add tests**: Write unit tests with Pester, workflow tests with BATS
4. **Monitor costs**: Use custom cost estimation tools (see [COST_ESTIMATION.md](COST_ESTIMATION.md))
5. **Configure monitoring**: Application Insights is included in infrastructure

---

**For Help**: Check documentation in `docs/` or project README
