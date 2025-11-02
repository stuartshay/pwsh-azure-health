# Scripts

This directory contains utility scripts for the Azure Health Monitoring Functions project.

## Directory Layout

- `ci/` – helpers that run in GitHub Actions or other continuous integration contexts.
- `deployment/` – tooling used to publish the Functions app to Azure.
- `local/` – local workstation helpers (environment validation, bootstrap installers, etc.).
- `install-hooks.sh`, `pre-commit-hook.sh` – git hook wiring and the consolidated check runner.

Agent-oriented automation does not yet have its own folder; today, the "agent" helpers we
maintain are simply the same local setup scripts developers rely on. If we later add
dedicated automation that does not belong to the local or deployment experiences, we can
introduce a scoped directory (for example, `agents/`) to keep the structure balanced.

## Pre-Commit Hooks

### Setup

To install the pre-commit hooks locally:

```bash
./scripts/install-hooks.sh
```

This will configure Git to automatically run quality checks before each commit.

### Manual Validation

To manually run all pre-commit checks without committing:

```bash
./scripts/pre-commit-hook.sh
```

### What Gets Checked

The pre-commit hook validates:

1. **Large Files**: Prevents files >500KB from being committed
2. **Merge Conflicts**: Detects unresolved merge conflict markers
3. **YAML Validation**: Ensures all .yml/.yaml files have valid syntax
4. **JSON Validation**: Ensures all .json files have valid syntax
5. **Trailing Whitespace**: Automatically removes trailing spaces (auto-fixed)
6. **PowerShell Linting**: Runs PSScriptAnalyzer on all .ps1/.psm1/.psd1 files
7. **Secret Detection**: Scans for common secret patterns (passwords, API keys, private keys)

### Skipping Hooks

In rare cases where you need to bypass the hooks (not recommended):

```bash
git commit --no-verify
```

## Other Scripts

### Deployment

- `deployment/deploy-to-azure.sh` - Deployment automation (see docs/DEPLOYMENT.md)

### Local Development

- `local/setup-local-dev.ps1` - Local development environment setup
- `local/install-dev-tools.sh` - Verifies tooling and points to installers
- `local/install-powershell.sh` - Installs PowerShell 7 on Debian/Ubuntu hosts
- `local/get-function-keys.ps1` - Downloads Azure Function keys and saves to `.keys/` directory
- `local/test-api.ps1` - Tests Function App API endpoints using saved function keys

#### Function Keys Management

Download and securely store function keys for local testing:

```bash
# Download keys for dev environment
pwsh scripts/local/get-function-keys.ps1

# Download keys for prod environment
pwsh scripts/local/get-function-keys.ps1 -Environment prod
```

Keys are saved to `.keys/` directory (excluded from git) with usage examples in `.keys/keys-info.txt`.

#### API Testing

Test your Function App endpoints using saved keys:

```bash
# Test health endpoint (no authentication)
pwsh scripts/local/test-api.ps1 -Endpoint health

# Test GetServiceHealth endpoint
pwsh scripts/local/test-api.ps1 -Endpoint GetServiceHealth

# Show detailed request/response info
pwsh scripts/local/test-api.ps1 -Endpoint GetServiceHealth -ShowDetails
```
