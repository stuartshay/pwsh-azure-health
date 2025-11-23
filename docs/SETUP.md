---
version: 1.0.0
last-updated: 2025-11-17
---

# Local Development Setup Guide

This guide walks you through setting up your local development environment for the Azure Health Monitoring Functions project.

## Prerequisites Installation

### 1. Install PowerShell 7.4+

**Windows:**
```powershell
winget install Microsoft.PowerShell
```

**macOS:**
```bash
brew install powershell/tap/powershell
```

**Linux (Ubuntu):**
```bash
sudo snap install powershell --classic
```

Verify installation:
```powershell
pwsh --version
```

### 2. Install .NET 8 SDK

Download from: https://dotnet.microsoft.com/download/dotnet/8.0

Verify installation:
```bash
dotnet --version
```

### 3. Install Azure Functions Core Tools

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
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4
```

Verify installation:
```bash
func --version
```

### 4. Install Azure CLI

**Windows:**
Download from: https://aka.ms/installazurecliwindows

**macOS:**
```bash
brew install azure-cli
```

**Linux:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Verify installation:
```bash
az --version
```

### 5. Install Visual Studio Code (Optional but Recommended)

Download from: https://code.visualstudio.com/

Install recommended extensions:
- Azure Functions
- PowerShell
- Azure Account
- EditorConfig for VS Code

## Project Setup

### 1. Clone the Repository

```bash
git clone https://github.com/stuartshay/pwsh-azure-health.git
cd pwsh-azure-health
```

### 2. Configure Local Settings

The `local.settings.json` file is not tracked in Git for security. You need to configure it manually inside the `src/` folder:

1. Copy the template file:
   ```bash
   cp src/local.settings.json.template src/local.settings.json
   ```
2. Update the `AZURE_SUBSCRIPTION_ID` value in `src/local.settings.json`:
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

### 3. Azure Authentication

#### Option A: Interactive Login (Recommended for Development)

```powershell
Connect-AzAccount
Set-AzContext -SubscriptionId "your-subscription-id"
```

#### Option B: Service Principal (CI/CD)

```powershell
$securePassword = ConvertTo-SecureString -String "your-password" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("your-app-id", $securePassword)
Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId "your-tenant-id"
```

### 4. Install PowerShell Dependencies (Optional)

While Azure Functions will auto-install dependencies, you can pre-install for faster development:

```powershell
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
Install-Module -Name Az.ResourceGraph -Repository PSGallery -Force -Scope CurrentUser
Install-Module -Name Az.Monitor -Repository PSGallery -Force -Scope CurrentUser
```

## Running the Function Locally

### Start the Function Host

Run the function host from the repository root and point it to the `src/` directory:

```bash
func start --script-root src
```

Expected output:
```
Azure Functions Core Tools
Core Tools Version:       4.x.xxxx
Function Runtime Version: 4.x.xxxx

Functions:
  GetServiceHealth: [GET,POST] http://localhost:7071/api/GetServiceHealth
```

### Test the Function

Open a new terminal and run:

```bash
curl "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

Or use PowerShell:
```powershell
Invoke-RestMethod -Uri "http://localhost:7071/api/GetServiceHealth?SubscriptionId=your-subscription-id"
```

## Debugging in VS Code

1. Open the project in VS Code
2. Press F5 or go to Run > Start Debugging
3. Set breakpoints in PowerShell files under `src/`
4. Make a request to the function
5. Execution will pause at breakpoints

## Troubleshooting

### Issue: "PowerShell module not found"

**Solution:**
```powershell
# Clear managed dependencies cache
Remove-Item -Path "$env:HOME/.azure/functions/managedDependencies" -Recurse -Force

# Restart the function host
func start --script-root src
```
