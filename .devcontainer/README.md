# DevContainer Configuration

This directory contains the DevContainer configuration for the Azure Health Monitoring Functions project. DevContainers provide a consistent, pre-configured development environment using Docker containers.

## What's Included

The DevContainer includes all required tools and dependencies:

- **PowerShell 7.4** - PowerShell runtime
- **.NET 8 SDK** - Required by Azure Functions
- **Azure Functions Core Tools v4** - Local function development and testing
- **Azure CLI** - Azure resource management
- **Node.js 20** - Required by Azure Functions Core Tools
- **Git** - Version control
- **PowerShell Modules**:
  - Az (latest)
  - Az.ResourceGraph (latest)
  - Az.Monitor (latest)
  - Pester (>=5.4.0) - Testing framework

## VS Code Extensions

The following extensions are automatically installed:
- Azure Functions
- PowerShell
- Azure Account
- EditorConfig for VS Code

## Getting Started

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop)
- [Visual Studio Code](https://code.visualstudio.com/)
- [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

### Using the DevContainer

1. **Open in DevContainer**:
   - Open the repository in VS Code
   - Click the green button in the bottom-left corner
   - Select "Reopen in Container"
   - Wait for the container to build (first time takes a few minutes)

2. **Authenticate with Azure**:
   ```bash
   az login
   ```

3. **Configure Local Settings**:
   - Edit `src/local.settings.json` with your Azure subscription ID
   - The file is created automatically from the template

4. **Start the Function App**:
   ```bash
   func start --script-root src
   ```

5. **Test the Function**:
   ```bash
   curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
   ```

## Features

### Port Forwarding

Port 7071 (Azure Functions default) is automatically forwarded, allowing you to access the function app from your host machine.

### Azure Credentials

You'll need to authenticate with Azure inside the DevContainer using `az login`. Credentials are stored within the container and will persist between sessions.

### PowerShell as Default

PowerShell is configured as the default terminal shell for the integrated terminal.

## Customization

You can customize the DevContainer by editing:
- `devcontainer.json` - Main configuration file
- `Dockerfile` - Container image definition
- `post-create.sh` - Post-creation setup script

## Troubleshooting

### Container Build Fails

If the container fails to build:
1. Check Docker is running
2. Try "Rebuild Container" from the command palette
3. Check Docker logs for specific errors

### PowerShell Modules Not Found

If PowerShell modules are missing:
```bash
bash .devcontainer/post-create.sh
```

### Azure CLI Authentication

If you need to authenticate or re-authenticate:
```bash
az login
```

## Benefits

- **Consistency**: Everyone uses the same development environment
- **Quick Setup**: No manual installation of tools and dependencies
- **Isolation**: Development environment is isolated from your host system
- **Portability**: Works on Windows, macOS, and Linux

## Additional Resources

- [VS Code DevContainers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [Azure Functions with DevContainers](https://docs.microsoft.com/en-us/azure/azure-functions/functions-develop-vs-code?tabs=csharp#development-container)
- [DevContainer Specification](https://containers.dev/)
