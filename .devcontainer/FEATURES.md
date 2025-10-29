# Dev Container Features Migration

This document describes the migration from manual installation in Dockerfile to using Dev Container Features.

## What Changed

### Before: Manual Installation in Dockerfile
Previously, we manually installed dependencies using apt-get and custom scripts:
- Git, curl, wget, ca-certificates
- Python 3, pip, venv
- Node.js 24 (via nodesource script)
- Non-root user creation (vscode)
- Sudo configuration

### After: Dev Container Features
Now using official Dev Container Features from https://containers.dev/features

## Features Used

### 1. Common Utilities (`ghcr.io/devcontainers/features/common-utils:2`)
**Replaces:**
- Manual git, curl, wget, ca-certificates installation
- Non-root user (vscode) creation
- Sudo configuration

**Configuration:**
```json
{
  "installZsh": false,
  "installOhMyZsh": false,
  "upgradePackages": true,
  "username": "vscode",
  "uid": "1000",
  "gid": "1000"
}
```

**Benefits:**
- Automatic user creation with proper permissions
- Pre-configured sudo access
- Common utilities installed and maintained
- Keeps packages up to date

### 2. Python (`ghcr.io/devcontainers/features/python:1`)
**Replaces:**
- Manual python3, python3-pip, python3-venv installation

**Configuration:**
```json
{
  "version": "3.10",
  "installTools": true
}
```

**Benefits:**
- Specific Python version control
- Pip and venv automatically configured
- Python tools (pipx, etc.) available
- Optimized for container usage

### 3. Node.js (`ghcr.io/devcontainers/features/node:1`)
**Replaces:**
- Manual Node.js installation via nodesource script

**Configuration:**
```json
{
  "version": "24",
  "nodeGypDependencies": true,
  "installYarnUsingApt": false
}
```

**Benefits:**
- LTS version pinning (Node.js 24)
- npm pre-configured
- Node-gyp dependencies for native modules
- Automatic PATH configuration

### 4. Azure CLI (`ghcr.io/devcontainers/features/azure-cli:1`)
**Already using** - No changes needed

### 5. .NET SDK (`ghcr.io/devcontainers/features/dotnet:2`)
**Already using** - No changes needed

## What Remains in Custom Scripts

### Dockerfile
- Base PowerShell image
- PowerShell shell configuration
- Comments documenting feature usage

### post-create.sh
- Azure Functions Core Tools (npm install) - No official feature available
- Pre-commit framework setup - Project-specific configuration
- PowerShell modules installation - Application-specific dependencies
- local.settings.json creation - Project template

## Benefits of Using Features

1. **Maintenance**: Features are maintained by the community
2. **Best Practices**: Features follow container best practices
3. **Consistency**: Same features work across different base images
4. **Updates**: Easy to update by changing version numbers
5. **Documentation**: Well-documented at containers.dev
6. **Compatibility**: Tested across different scenarios
7. **Smaller Dockerfiles**: Less custom code to maintain

## Dockerfile Size Comparison

**Before:** ~60 lines with manual installations
**After:** ~10 lines, most work delegated to features

## Testing

After migration, verify all tools are available:
```bash
# Check versions
pwsh --version          # PowerShell 7.5.4
python3 --version       # Python 3.10.x
node --version          # Node.js 24.x.x
npm --version           # npm 10.x.x
git --version           # Git 2.x.x
az version              # Azure CLI
dotnet --version        # .NET 8.0.x
func --version          # Azure Functions Core Tools 4.x

# Check user
whoami                  # should be 'vscode'
sudo -v                 # should work without password

# Check pre-commit
pre-commit --version    # pre-commit 4.x.x
```

## Migration Path for Other Projects

To adopt this pattern in other projects:

1. Identify manual installations in Dockerfile
2. Search for matching features at https://containers.dev/features
3. Add features to `devcontainer.json`
4. Remove redundant Dockerfile RUN commands
5. Keep project-specific installations in post-create scripts
6. Test thoroughly

## Available Feature Catalogs

- **Official Features**: https://github.com/devcontainers/features
- **Community Features**: https://containers.dev/collections
- **Create Custom Features**: https://containers.dev/guide/creating-features

## Future Considerations

Consider creating a custom feature for:
- Azure Functions Core Tools installation
- PowerShell module installation pattern
- Pre-commit with specific hooks

This would make the pattern reusable across multiple Azure Functions projects.
