# Azure Health Monitoring Functions - Project Summary

## Overview

This project provides an enterprise-ready Azure Functions application for monitoring Azure Service Health using PowerShell. It has been structured with best practices for local development, deployment, and maintenance.

## What Has Been Created

### Core Azure Functions Infrastructure

1. **src/host.json** - Function app configuration
   - Application Insights integration
   - Function timeout settings (10 minutes)
   - HTTP route prefix configuration
   - Extension bundle v4 configuration

2. **src/requirements.psd1** - PowerShell module dependencies
   - Az module (v12.*)
   - Az.ResourceGraph (v1.*)
   - Az.Monitor (v5.*)
   - Automatic managed dependency installation

3. **src/profile.ps1** - PowerShell startup script
   - Managed Identity authentication
   - Cold start initialization
   - Shared utility functions

### Sample Function

**src/GetServiceHealth** - HTTP-triggered function
- Retrieves Azure Service Health events via Resource Graph
- Supports GET and POST methods
- Query parameters or JSON body input
- Returns structured JSON response with:
  - Active service issues
  - Planned maintenance events
  - Last 7 days of health data

### Development Configuration

1. **.vscode/** - VS Code settings
   - Recommended extensions
   - Debug configuration for PowerShell
   - Build tasks
   - Editor settings

2. **.editorconfig** - Code formatting rules
   - PowerShell: 4 spaces
   - JSON: 2 spaces
   - Consistent line endings

3. **.PSScriptAnalyzerSettings.psd1** - Code quality rules
   - PowerShell best practices
   - Consistent indentation
   - Approved verbs enforcement

4. **src/local.settings.json.template** - Local configuration template
   - PowerShell 7.4 runtime
   - Development storage
   - Subscription ID placeholder

### Deployment & Operations

1. **scripts/deployment/deploy-to-azure.sh** - Automated Azure deployment
   - Creates resource group
   - Provisions Function App
   - Configures Application Insights
   - Enables Managed Identity
   - Assigns RBAC roles

2. **scripts/local/setup-local-dev.ps1** - Local setup automation
   - Validates prerequisites
   - Installs PowerShell modules
   - Checks Azure authentication
   - Verifies configuration

### Documentation

1. **README.md** - Project overview and main documentation
2. **QUICKSTART.md** - 5-minute setup guide
3. **CONTRIBUTING.md** - Development guidelines
4. **docs/SETUP.md** - Detailed setup instructions
5. **docs/DEPLOYMENT.md** - Azure deployment guide
6. **docs/API.md** - Complete API reference
7. **docs/BEST_PRACTICES.md** - Development best practices

### Configuration Files

1. **.gitignore** - Git exclusions
   - Azure Functions artifacts
   - PowerShell temporary files
   - IDE files (excluding .vscode)
   - Environment files

2. **.funcignore** - Deployment exclusions
   - Test files
   - Documentation
   - Development artifacts

## Project Structure

```
pwsh-azure-health/
├── docs/                          # Documentation
│   ├── API.md
│   ├── BEST_PRACTICES.md
│   ├── DEPLOYMENT.md
│   └── SETUP.md
├── scripts/                       # Automation scripts
│   ├── ci/
│   ├── deployment/
│   │   └── deploy-to-azure.sh
│   └── local/
│       └── setup-local-dev.ps1
├── src/                           # Function app source
│   ├── GetServiceHealth/
│   │   ├── function.json
│   │   └── run.ps1
│   ├── shared/
│   │   ├── Modules/
│   │   │   └── ServiceHealth.psm1
│   │   └── Scripts/
│   │       └── HttpHelpers.ps1
│   ├── host.json
│   ├── local.settings.json.template
│   ├── profile.ps1
│   └── requirements.psd1
├── tests/
│   └── unit/
│       └── ServiceHealth.Tests.ps1
├── .editorconfig
├── .funcignore
├── .gitignore
├── .PSScriptAnalyzerSettings.psd1
├── CONTRIBUTING.md
├── LICENSE
├── QUICKSTART.md
└── README.md
```

## Enterprise Features

### Security
- Managed Identity support
- Function-level authentication
- No hardcoded credentials
- Secure configuration management

### Scalability
- Consumption plan ready
- Premium plan compatible
- Stateless design
- Efficient Resource Graph queries

### Observability
- Application Insights integration
- Structured logging
- Custom metrics support
- Error tracking

### Development Experience
- VS Code integration
- PowerShell debugging
- Code quality tools
- Automated setup scripts

### Documentation
- Comprehensive guides
- API reference
- Best practices
- Quick start

## Getting Started

1. **Prerequisites:**
   - PowerShell 7.4+
   - Azure Functions Core Tools v4
   - Azure subscription

2. **Quick Start:**
   ```bash
   git clone https://github.com/stuartshay/pwsh-azure-health.git
   cd pwsh-azure-health
   cp local.settings.json.template local.settings.json
   # Edit local.settings.json with your subscription ID
   func start
   ```

3. **Deploy to Azure:**
   ```bash
   ./scripts/deploy-to-azure.sh
   ```

## Next Steps

Potential enhancements:
1. Add more Service Health query functions
2. Implement alerting mechanisms
3. Create dashboard visualizations
4. Add automated tests (Pester)
5. Implement CI/CD pipeline
6. Add additional health metrics
7. Create scheduled trigger functions
8. Implement caching layer

## Resources

- [Azure Functions PowerShell Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-powershell)
- [Azure Service Health](https://docs.microsoft.com/en-us/azure/service-health/)
- [Azure Resource Graph](https://docs.microsoft.com/en-us/azure/governance/resource-graph/)

## Support

For issues or questions:
- Check the documentation in the `docs/` folder
- Review the QUICKSTART.md guide
- Open an issue on GitHub

---

**Project Status:** ✅ Ready for local development and Azure deployment
**Version:** 1.0.0
**Last Updated:** October 28, 2025
