# Pre-commit Hooks Guide

This project uses [pre-commit](https://pre-commit.com/) to automatically validate code quality before commits are made. This ensures consistent code quality and catches common issues early.

## What is Pre-commit?

Pre-commit is a framework for managing and maintaining multi-language pre-commit hooks. It runs configured checks on your staged files before allowing a commit, helping catch issues before they enter the codebase.

## Automatic Setup

If you're using the DevContainer, pre-commit is automatically installed and configured when the container is created. No manual setup required!

## Manual Installation

If you're not using the DevContainer:

### Install pre-commit:
```bash
# Using pip
pip install pre-commit

# Using homebrew (macOS)
brew install pre-commit

# Using conda
conda install -c conda-forge pre-commit
```

### Install the hooks:
```bash
# Install pre-commit hooks
pre-commit install

# Install pre-push hooks
pre-commit install --hook-type pre-push
```

## Configured Hooks

### Standard Checks
- **trailing-whitespace**: Removes trailing whitespace from files
- **end-of-file-fixer**: Ensures files end with a newline
- **check-yaml**: Validates YAML file syntax
- **check-json**: Validates JSON file syntax
- **check-added-large-files**: Prevents committing large files (>500KB)
- **check-merge-conflict**: Detects merge conflict markers
- **detect-private-key**: Prevents committing private keys
- **mixed-line-ending**: Ensures consistent line endings (LF)
- **no-commit-to-branch**: Prevents direct commits to master/main

### Security
- **gitleaks**: Scans for secrets, passwords, API keys, and tokens

### YAML Linting
- **yamllint**: Advanced YAML validation with custom rules

### Bicep and Infrastructure
- **actionlint**: Validates GitHub Actions workflow files for syntax and best practices
- **Bicep Build Validation**: Validates Bicep infrastructure templates using `az bicep build`

### PowerShell Specific
- **PSScriptAnalyzer**: Lints PowerShell code for best practices and errors
- **Pester Tests**: Runs unit tests before pushing (pre-push hook only)

## Usage

### Running Hooks

Hooks run automatically on commit:
```bash
git commit -m "Your commit message"
```

Run hooks manually on all files:
```bash
pre-commit run --all-files
```

Run a specific hook:
```bash
pre-commit run trailing-whitespace --all-files
pre-commit run psscriptanalyzer --all-files
pre-commit run bicep-build --all-files
pre-commit run actionlint --all-files
```

Run hooks on staged files only:
```bash
pre-commit run
```

### Skipping Hooks

Sometimes you may need to skip hooks (use sparingly):

```bash
# Skip all hooks for one commit
git commit --no-verify -m "Emergency fix"

# Skip specific hook
SKIP=psscriptanalyzer git commit -m "WIP: work in progress"

# Skip multiple hooks
SKIP=psscriptanalyzer,pester-tests,bicep-build git commit -m "WIP"
```

### Updating Hooks

Keep hooks up to date with the latest versions:

```bash
pre-commit autoupdate
```

This updates the hook versions in `.pre-commit-config.yaml`.

## Hook Configuration

The hooks are configured in `.pre-commit-config.yaml` at the project root.

### Customizing Hooks

To modify hook behavior, edit `.pre-commit-config.yaml`. For example:

```yaml
- id: check-added-large-files
  args: [--maxkb=1000]  # Change max file size to 1MB
```

### Disabling a Hook

Comment out the hook in `.pre-commit-config.yaml`:

```yaml
# - id: trailing-whitespace
#   args: [--markdown-linebreak-ext=md]
```

### Adding New Hooks

Browse available hooks at https://pre-commit.com/hooks.html

Add new hooks to `.pre-commit-config.yaml` under the appropriate repo.

## Troubleshooting

### Hook Fails with "command not found"

Ensure the required tools are installed:
- PowerShell: `pwsh --version`
- Python: `python3 --version`
- Pester: `pwsh -Command "Get-Module -ListAvailable Pester"`
- Azure CLI: `az --version`
- actionlint: `actionlint --version`

### PSScriptAnalyzer Issues

Run PSScriptAnalyzer manually to see detailed output:
```bash
pwsh -Command "Invoke-ScriptAnalyzer -Path . -Recurse -Settings ./.PSScriptAnalyzerSettings.psd1"
```

### Pester Tests Fail

Run tests manually to debug:
```bash
pwsh -Command "Import-Module Pester; Invoke-Pester -Path ./tests/unit -Output Detailed"
```

### Bicep Validation Issues

Run Bicep build manually to see detailed errors:
```bash
az bicep build --file infrastructure/main.bicep
```

### GitHub Actions Workflow Issues

Run actionlint manually to see detailed output:
```bash
actionlint .github/workflows/*.yml
```

### Reset Hooks

If hooks are misbehaving, reinstall them:
```bash
pre-commit uninstall
pre-commit install
pre-commit install --hook-type pre-push
```

### Clear Hook Cache

If hooks aren't updating:
```bash
pre-commit clean
pre-commit install --install-hooks
```

## CI/CD Integration

Pre-commit can also run in CI/CD:

### GitHub Actions
The project uses pre-commit in GitHub Actions for consistency. See `.github/workflows/lint-and-test.yml`.

### Pre-commit.ci
The configuration includes settings for [pre-commit.ci](https://pre-commit.ci), a free CI service for pre-commit:
- Auto-fixes issues in PRs
- Keeps hooks updated automatically
- Runs weekly updates

## Best Practices

1. **Run locally before pushing**: Hooks catch issues early
2. **Don't skip hooks without reason**: They're there for code quality
3. **Keep hooks updated**: Run `pre-commit autoupdate` periodically
4. **Fix issues, don't disable hooks**: Address the root cause
5. **Test changes**: Ensure hooks work after modifying `.pre-commit-config.yaml`

## Additional Resources

- [Pre-commit Documentation](https://pre-commit.com/)
- [Pre-commit Hooks Repository](https://github.com/pre-commit/pre-commit-hooks)
- [PSScriptAnalyzer Rules](https://github.com/PowerShell/PSScriptAnalyzer)
- [GitLeaks Documentation](https://github.com/gitleaks/gitleaks)

## Custom Scripts

The project also includes custom pre-commit scripts in `scripts/`:
- `install-hooks.sh`: Legacy hook installer
- `pre-commit-hook.sh`: Legacy validation script

These are maintained for compatibility but the modern pre-commit framework is recommended.
