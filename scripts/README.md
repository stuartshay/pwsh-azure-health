# Scripts

This directory contains utility scripts for the Azure Health Monitoring Functions project.

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
