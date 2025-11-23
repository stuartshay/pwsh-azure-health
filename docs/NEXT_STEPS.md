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

---
version: 1.0.0
last-updated: 2025-11-17
---

# Next Steps & Improvements

Once local development is working:

1. **Deploy to Azure**: See [DEPLOYMENT.md](DEPLOYMENT.md) for deployment options
2. **Set up CI/CD**: Configure GitHub Actions (see [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md))
3. **Add tests**: Write unit tests with Pester, workflow tests with BATS
4. **Monitor costs**: Use custom cost estimation tools (see [COST_ESTIMATION.md](COST_ESTIMATION.md))
5. **Configure monitoring**: Application Insights is included in infrastructure

---

## Future Improvements 💡

### High Priority

#### 1. Production Environment Setup
**Status:** ✅ Completed
**Implemented:** November 17, 2025

Production environment created in GitHub with proper federated credentials. Validation script now shows 17/17 checks passed.

**Benefit:** Complete deployment pipeline, better separation of dev/prod environments.

---

#### 2. Automated Pricing Freshness Check
**Status:** ✅ Completed
**Implemented:** November 17, 2025

Added automated check in `.github/workflows/lint-and-test.yml` that validates pricing data freshness:
- Checks `infrastructure/cost-config.json` lastUpdated date
- Warns if pricing data is older than 90 days
- Provides actionable update instructions in workflow output

**Benefit:** Ensures cost estimates remain accurate over time.

---

#### 3. Enhanced Error Handling in PowerShell Functions
**Status:** 💭 Enhancement
**Current State:** Some functions could benefit from more detailed error handling.

**Action:** Add comprehensive error handling pattern:
```powershell
function Invoke-SafeOperation {
    [CmdletBinding()]
    param()

    try {
        # Operation logic
    }
    catch {
        Write-Error "Operation failed: $($_.Exception.Message)"
        Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red

        # Log to Application Insights if available
        if ($env:APPLICATIONINSIGHTS_CONNECTION_STRING) {
            # Send custom telemetry
        }

        throw
    }
}
```

**Benefit:** Better debugging, improved observability in production.

---

#### 4. Integration Tests for GitHub Actions Workflows
**Status:** 💭 Planned
**Current State:** 143 BATS tests, but no end-to-end workflow testing.

**Action:** Add integration tests in `tests/workflows/integration/`:
```bash
# tests/workflows/integration/full-deployment.bats
@test "complete infrastructure deployment workflow" {
  # Test full deploy → verify → cost analysis pipeline
  # Could run against a separate test subscription
}
```

**Benefit:** Catch workflow-level issues before they reach production.

---

#### 5. Monitoring Dashboard with Application Insights
**Status:** 💭 Planned
**Current State:** Application Insights is deployed but no pre-built dashboards.

**Action:** Create an Application Insights workbook for monitoring:
- GetServiceHealthTimer execution frequency and duration
- Cache hit/miss rates
- Error rates by function
- Cost trends over time
- API response times

**Benefit:** Better visibility into production health and performance.

---

### Medium Priority

#### 6. Dependency Version Pinning
**Status:** ✅ Completed
**Implemented:** November 17, 2025

Pinned exact versions for all PowerShell modules and Azure Bicep API versions:
- **Root requirements.psd1**: Development dependencies (11 modules pinned)
  - Az.Accounts: 5.3.0, Az.Storage: 9.3.0, Az.ResourceGraph: 1.2.1
  - Az.Resources: 8.1.1, Az.Monitor: 6.0.3, Az.Functions: 4.2.1, Az.Websites: 3.4.2
  - Pester: 5.7.1, PSScriptAnalyzer: 1.24.0, PSRule: 2.9.0, PSRule.Rules.Azure: 1.39.1
- **src/requirements.psd1**: Azure Functions runtime (3 modules pinned)
  - Az.Accounts: 5.3.0, Az.Storage: 9.3.0, Az.ResourceGraph: 1.2.1
- **infrastructure/main.bicep**: Azure API versions updated to latest stable
  - Storage: 2023-05-01 → 2025-06-01, Web: 2023-12-01 → 2025-03-01
  - Managed Identity: 2023-01-31 → 2024-11-30
- **Renovate configured**: Automated dependency updates for PowerShell modules grouped into single PRs

**Benefit:** Prevents breaking changes from upstream updates, ensures reproducible builds and deployments.

---

#### 7. Cache Invalidation Strategy
**Status:** 💭 Enhancement
**Current State:** Timer-based cache updates (every 15 minutes).

**Action:** Add manual cache invalidation endpoint:
```powershell
# New function: InvalidateCache
function InvalidateCache {
    # Force refresh of service health cache
    # Useful after Azure incidents
}
```

**Benefit:** Immediate updates during critical Azure incidents.

---

#### 8. Regional Deployment Support
**Status:** 💭 Future Enhancement
**Current State:** Single region deployment (East US).

**Action:** Add multi-region support for high availability:
- Bicep parameter for primary/secondary regions
- Traffic Manager or Front Door configuration
- Cross-region cache replication strategy

**Benefit:** Better disaster recovery and global performance.

---

#### 9. Pre-commit Hook for Bicep Validation
**Status:** ✅ Completed
**Implemented:** November 17, 2025

Added Bicep linting to pre-commit hooks in `.pre-commit-config.yaml`:
- `bicep-lint` hook runs `az bicep lint` on all `.bicep` files
- `bicep-build` hook validates Bicep can compile successfully
- Both hooks run automatically on commit for modified Bicep files
- Catches syntax errors, best practice violations, and compilation issues

**Benefit:** Catch IaC issues before they reach CI/CD.

---

#### 10. Documentation Versioning
**Status:** ✅ Completed
**Current State:** Documentation is in markdown but no version tracking.

**Action:** Add document versions and last-updated dates:
```markdown
---
version: 1.2.0
last-updated: 2025-11-17
---
```

**Implemented:** November 17, 2025

Added YAML front matter with version metadata to all documentation files:
- README.md: v2.0.0 (reflects major User-Assigned Identity architecture changes)
- All docs in `docs/` directory: v1.0.0 (initial versioning baseline)
- SECURITY_PERMISSIONS.md: Already had v2.0.0 metadata
- Metadata includes: `version` (semantic versioning) and `last-updated` (YYYY-MM-DD)

Created DOCUMENTATION_STANDARDS.md with versioning guidelines:
- Version format: Semantic versioning (major.minor.patch)
- Major version: Significant restructuring or architectural changes
- Minor version: Content updates, additions, or corrections
- Update date format: ISO 8601 (YYYY-MM-DD)

**Benefit:** Track documentation changes and identify outdated guides.

---

### Future Enhancements

#### 11. API Rate Limiting
Add rate limiting to public HTTP endpoints to prevent abuse.

#### 12. GraphQL API Layer
Alternative API layer for more efficient querying of service health data.

#### 13. Notification Webhooks
Push notifications to Teams/Slack when critical service issues detected.

#### 14. Historical Data Retention
Long-term storage of service health events in Azure SQL/Cosmos DB for trend analysis.

#### 15. Custom Metrics Export
Export custom metrics to Prometheus/Grafana for unified monitoring.

---

**Project Health Score: 9/10** ✅

**Strengths:**
- ✅ Excellent documentation (17+ docs)
- ✅ Comprehensive testing (143 BATS + 8 Pester tests)
- ✅ Strong DevOps practices (pre-commit, GitHub Actions)
- ✅ Security best practices (managed identity, RBAC)
- ✅ Cost management (estimation + analysis)
- ✅ IaC with Bicep (declarative, idempotent)

---

**For Help**: Check documentation in `docs/` or project README
