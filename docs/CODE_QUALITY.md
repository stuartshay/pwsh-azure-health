# Code Quality and CI/CD

This document describes the automated quality checks and continuous integration setup for the Azure Health Monitoring Functions project.

## Overview

This project enforces strict enterprise development standards through:

1. **Pre-commit Hooks** - Local validation before commits
2. **GitHub Actions** - Automated CI pipeline for all changes
3. **Code Linting** - PSScriptAnalyzer for PowerShell quality
4. **Security Scanning** - Secret detection and vulnerability scanning

## Pre-Commit Hooks

### Quick Start

Install the pre-commit hooks locally:

```bash
./scripts/install-hooks.sh
```

The hooks will automatically run on every `git commit`. If any check fails, the commit will be blocked.

### What Gets Validated

| Check | Description | Auto-Fix |
|-------|-------------|----------|
| Large Files | Prevents files >500KB from being committed | ❌ |
| Merge Conflicts | Detects unresolved conflict markers | ❌ |
| YAML Syntax | Validates .yml and .yaml files | ❌ |
| JSON Syntax | Validates .json files | ❌ |
| Trailing Whitespace | Removes trailing spaces from all files | ✅ |
| PowerShell Linting | Runs PSScriptAnalyzer on .ps1/.psm1/.psd1 | ❌ |
| Secret Detection | Scans for passwords, API keys, private keys | ❌ |

### Manual Testing

To run the pre-commit checks without committing:

```bash
./scripts/pre-commit-hook.sh
```

### Bypassing Hooks

**Not recommended**, but in rare cases you can skip hooks:

```bash
git commit --no-verify
```

## GitHub Actions Workflows

### Lint and Test Workflow

**File:** `.github/workflows/lint-and-test.yml`

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual trigger via workflow_dispatch

**Jobs:**

#### 1. PowerShell Linting
- Installs PowerShell and PSScriptAnalyzer
- Runs linting on all PowerShell files in `./src`
- Fails on any errors, warns on issues

#### 2. PowerShell Tests
- Installs PowerShell, Pester, and Az modules
- Runs Pester unit tests from `./tests/unit`
- Uploads test results as artifacts
- Fails if any tests fail

#### 3. YAML Validation
- Installs yamllint
- Validates all YAML files in `.github/` and `.devcontainer/`
- Checks syntax and basic formatting

#### 4. Security Scanning
- Runs Gitleaks to detect secrets
- Scans entire repository history
- Fails if any secrets are detected

### Viewing Results

1. Go to the **Actions** tab in GitHub
2. Click on a workflow run to see details
3. Review job logs and test results
4. Download test artifacts if needed

## Local Development Workflow

### First Time Setup

```bash
# Clone the repository
git clone https://github.com/stuartshay/pwsh-azure-health.git
cd pwsh-azure-health

# Install pre-commit hooks
./scripts/install-hooks.sh

# Install PowerShell modules
pwsh -Command "Install-Module -Name PSScriptAnalyzer, Pester -Force"
```

### Before Committing

```bash
# Run linting
pwsh -Command "Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./.PSScriptAnalyzerSettings.psd1"

# Run tests
pwsh -Command "Invoke-Pester -Path ./tests/unit -Output Detailed"

# Run pre-commit checks (optional - will run automatically on commit)
./scripts/pre-commit-hook.sh
```

### Making a Commit

```bash
# Stage your changes
git add .

# Commit (pre-commit hooks run automatically)
git commit -m "feat: add new feature"

# If hooks fail, fix issues and try again
git add .
git commit -m "feat: add new feature"
```

## PowerShell Code Quality Standards

### PSScriptAnalyzer Rules

Configuration: `.PSScriptAnalyzerSettings.psd1`

**Key Rules:**
- Use approved PowerShell verbs (Get-, Set-, New-, etc.)
- Avoid cmdlet aliases
- Consistent indentation (4 spaces)
- Consistent whitespace
- Proper casing
- Comment-based help for functions

### Common Issues and Fixes

#### Trailing Whitespace
**Issue:** Lines end with spaces
**Fix:** Automatically fixed by pre-commit hook

#### Write-Host Usage
**Issue:** `Write-Host` is not recommended
**Fix:** Use `Write-Output`, `Write-Verbose`, or `Write-Information`

#### Inconsistent Indentation
**Issue:** Mixed tabs and spaces
**Fix:** Use 4 spaces (configured in .editorconfig)

#### Missing Comment Help
**Issue:** Functions lack documentation
**Fix:** Add comment-based help:

```powershell
<#
.SYNOPSIS
    Brief description

.DESCRIPTION
    Detailed description

.PARAMETER ParamName
    Parameter description

.EXAMPLE
    Example usage
#>
function Get-Something {
    # ...
}
```

## Troubleshooting

### Pre-commit Hook Issues

**Hook not running:**
```bash
# Reinstall the hooks
./scripts/install-hooks.sh
```

**Hook fails on PowerShell check:**
```bash
# Ensure PowerShell is installed
pwsh --version

# Install PSScriptAnalyzer
pwsh -Command "Install-Module -Name PSScriptAnalyzer -Force"
```

### GitHub Actions Issues

**Workflow not triggering:**
- Check if you're pushing to `main` or `develop`
- Verify workflow file syntax is valid
- Check Actions tab for disabled workflows

**Linting fails in CI but passes locally:**
- Ensure you're using the same PSScriptAnalyzer settings
- Run: `pwsh -Command "Invoke-ScriptAnalyzer -Path ./src -Recurse -Settings ./.PSScriptAnalyzerSettings.psd1"`

**Tests fail in CI but pass locally:**
- Check test output in workflow logs
- Verify all required modules are installed
- Look for environment-specific issues

## Contributing

When contributing to this project:

1. **Install hooks** before making changes
2. **Run tests** before pushing
3. **Fix all linting issues** before creating a PR
4. **Review CI results** and fix any failures
5. **Document** any new features or changes

All pull requests must pass:
- ✅ Pre-commit validation
- ✅ PSScriptAnalyzer linting
- ✅ Pester unit tests
- ✅ Security scanning

## Additional Resources

- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [PowerShell Best Practices](https://poshcode.gitbooks.io/powershell-practice-and-style/)
- [Pester Documentation](https://pester.dev)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
