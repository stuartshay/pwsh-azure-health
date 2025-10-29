# Local Development Setup - Next Steps

## Current Status ✅

The following have been configured and committed:

- ✅ **Azurite Auto-Start**: Automatically installs and starts in DevContainer post-create
- ✅ **Port Forwarding**: Ports 10000-10002 configured for Blob, Queue, Table services
- ✅ **Azure Developer CLI**: Added as a DevContainer feature
- ✅ **Connection String**: Template updated with Azurite endpoints
- ✅ **Helper Script**: `scripts/local/start-azurite.sh` for manual control
- ✅ **Documentation**: Complete guide in `docs/LOCAL_STORAGE.md`

## Required Actions 🔧

To complete your local development environment setup:

### 1. Rebuild DevContainer

**Action**: Rebuild the DevContainer to apply Azurite changes

```bash
# In VS Code Command Palette (F1 or Ctrl+Shift+P):
Dev Containers: Rebuild Container
```

**Why**: The new post-create script needs to run to install and start Azurite

**Time**: ~5-10 minutes for full rebuild

**Note**: If the build fails due to network issues (e.g., Azure Functions Core Tools download), you can manually install tools after the container starts:

```bash
# Manual installation script
./scripts/local/install-dev-tools.sh

# Or install individually
npm install -g azure-functions-core-tools@4
npm install -g azurite
```

### 2. Verify Azurite After Rebuild

After the rebuild completes, verify Azurite is running:

```bash
# Check process
ps aux | grep azurite

# Check ports are listening
netstat -tlnp | grep -E '10000|10001|10002'

# Test blob endpoint
curl http://127.0.0.1:10000/devstoreaccount1?comp=list

# View logs if needed
cat /workspaces/pwsh-azure-health/.azurite/debug.log
```

**Expected**: You should see azurite running and ports 10000-10002 listening

### 3. Azure Authentication

**Action**: Authenticate with Azure CLI

```bash
# Login to Azure
az login

# Set default subscription (replace with your subscription ID)
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify authentication
az account show
```

**Why**: The GetServiceHealth function needs Azure credentials to query Service Health

### 4. Update Local Settings

**Action**: Edit `src/local.settings.json` with your subscription ID

```json
{
  "Values": {
    "AZURE_SUBSCRIPTION_ID": "YOUR_SUBSCRIPTION_ID_HERE",
    ...
  }
}
```

**Why**: The function needs a subscription ID to query Service Health

**Note**: This file is in `.gitignore` and won't be committed

### 5. Test the Function

**Action**: Start and test the Azure Function locally

```bash
# Navigate to function directory
cd src

# Start the Functions host
func start

# In another terminal, test the function
curl "http://localhost:7071/api/GetServiceHealth?subscriptionId=YOUR_SUBSCRIPTION_ID"
```

**Expected**: You should see Service Health data returned as JSON

## Verification Checklist 📋

After completing the steps above, verify:

- [ ] Azurite is running (ports 10000-10002 active)
- [ ] Azure CLI is authenticated (`az account show` works)
- [ ] Subscription ID is set in `local.settings.json`
- [ ] Azure Functions host starts without errors
- [ ] GetServiceHealth function responds to HTTP requests
- [ ] Function can query Azure Service Health successfully

## Troubleshooting 🔍

### Azurite Not Running

```bash
# Start manually
./scripts/local/start-azurite.sh

# Or directly
azurite --silent --location ~/.azurite --debug ~/.azurite/debug.log \
  --blobPort 10000 --queuePort 10001 --tablePort 10002 \
  --blobHost 0.0.0.0 --queueHost 0.0.0.0 --tableHost 0.0.0.0 &
```

### Azure Authentication Issues

```bash
# Clear cached credentials
az account clear

# Login again with device code (if browser doesn't work)
az login --use-device-code

# List available subscriptions
az account list --output table
```

### Function Connection Errors

1. Check Azurite is running
2. Verify connection string in `src/local.settings.json`
3. Check ports are forwarded in VS Code (PORTS tab)
4. Restart Functions host: `cd src && func start`

### Permission Errors

```bash
# Check Service Health permissions for your account
az role assignment list --assignee YOUR_EMAIL --output table

# You may need "Reader" role on the subscription
az role assignment create --role "Reader" \
  --assignee YOUR_EMAIL \
  --subscription YOUR_SUBSCRIPTION_ID
```

## Documentation References 📚

- **Azurite Setup**: `docs/LOCAL_STORAGE.md`
- **Project Setup**: `docs/SETUP.md`
- **Deployment Guide**: `docs/DEPLOYMENT.md`
- **API Documentation**: `docs/API.md`
- **DevContainer Features**: `.devcontainer/FEATURES.md`
- **Pre-commit Hooks**: `docs/PRE_COMMIT.md`

## VS Code Tasks (Optional) 🎯

Consider creating VS Code tasks for common operations:

Create `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Start Azurite",
      "type": "shell",
      "command": "./scripts/local/start-azurite.sh",
      "problemMatcher": [],
      "group": "none"
    },
    {
      "label": "Start Azure Functions",
      "type": "shell",
      "command": "cd src && func start",
      "problemMatcher": [],
      "group": "none",
      "isBackground": true
    },
    {
      "label": "Run Tests",
      "type": "shell",
      "command": "pwsh -File tests/unit/ServiceHealth.Tests.ps1",
      "problemMatcher": [],
      "group": "test"
    }
  ]
}
```

Then run tasks via: **Terminal > Run Task...**

## What's Next? 🚀

Once local development is working:

1. **Implement Additional Functions**: Add more Azure health monitoring endpoints
2. **Add Integration Tests**: Test against Azurite storage
3. **CI/CD Pipeline**: Deploy to Azure via GitHub Actions
4. **Monitoring**: Configure Application Insights
5. **Documentation**: Update API docs with new endpoints

## Support 💬

If you encounter issues:

1. Check the relevant documentation in `docs/`
2. Review logs in `~/.azurite/debug.log`
3. Run pre-commit hooks manually: `pre-commit run --all-files`
4. Rebuild container if configuration changes aren't applied

---

**Last Updated**: Configuration committed to `develop` branch
**Commit**: feat: Add Azurite for local Azure Storage emulation
