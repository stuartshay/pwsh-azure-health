#!/bin/bash
# Exit on error for critical failures, but allow some steps to fail gracefully
set -e

echo "=================================="
echo "Setting up DevContainer environment..."
echo "=================================="

# Note: Base tools installed via Dev Container Features:
# - common-utils: git, curl, wget, sudo, non-root user
# - python: Python 3.10, pip, venv
# - node: Node.js 24 (via nvm)
# - azure-cli: Azure CLI
# - dotnet: .NET 8 SDK
# - docker-in-docker: Docker daemon
# - github-cli: gh CLI tool
# - pre-commit: pre-commit framework
# - azure-functions-core-tools: Azure Functions Core Tools v4
# - azd: Azure Developer CLI
# Note: Azurite is installed via VS Code extension (azurite.azurite)

# Wait for nvm to be available (features may still be initializing)
echo "Waiting for Node.js installation to complete..."
sleep 5

# Find and set nvm/node paths
if [ -d "/usr/local/share/nvm" ]; then
    export NVM_DIR="/usr/local/share/nvm"
    # Source nvm if available
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Try common node/npm locations
for node_path in \
    "/usr/local/share/nvm/current/bin" \
    "/usr/local/lib/node_modules/npm/bin" \
    "/usr/local/bin" \
    "$HOME/.nvm/current/bin"; do
    if [ -d "$node_path" ] && [ -x "$node_path/npm" ]; then
        export PATH="$node_path:$PATH"
        echo "Found npm at: $node_path"
        break
    fi
done

# Verify npm is available
if ! command -v npm &> /dev/null; then
    echo "ERROR: npm not found after searching common locations."
    echo "Searching for node/npm..."
    find /usr/local -name "npm" -type f 2>/dev/null || echo "npm not found in /usr/local"
    find /home -name "npm" -type f 2>/dev/null || echo "npm not found in /home"
    echo "PATH: $PATH"
    echo "Please check that the Node.js feature installed correctly."
    exit 1
fi

echo "✅ Found npm: $(which npm)"
echo "✅ npm version: $(npm --version)"
echo "✅ node version: $(node --version)"

# Note: Azure Functions Core Tools is installed via DevContainer Feature
# Verify it's available
if command -v func &> /dev/null; then
    echo "✅ Azure Functions Core Tools: $(func --version)"
else
    echo "⚠️  Azure Functions Core Tools not found"
fi

# Install/fix Bicep CLI
echo "Setting up Bicep CLI..."
if [ -f "$HOME/.azure/bin/bicep" ]; then
    # Remove potentially corrupted bicep binary
    rm -f "$HOME/.azure/bin/bicep"
fi

# Install Bicep for Linux x64
mkdir -p "$HOME/.azure/bin"
curl -sSL -o "$HOME/.azure/bin/bicep" https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
chmod +x "$HOME/.azure/bin/bicep"

# Verify Bicep installation
if command -v bicep &> /dev/null; then
    echo "✅ Bicep CLI: $(bicep --version)"
elif [ -x "$HOME/.azure/bin/bicep" ]; then
    echo "✅ Bicep CLI: $("$HOME"/.azure/bin/bicep --version)"
else
    echo "⚠️  Bicep CLI installation may have failed"
fi

# Note: Azurite is managed via VS Code extension (azurite.azurite)
# Create the workspace directory for Azurite data
echo "Creating Azurite workspace directory..."
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
mkdir -p "${WORKSPACE_DIR}/.azurite"
echo "✅ Azurite directory ready at ${WORKSPACE_DIR}/.azurite"
echo "ℹ️  Start Azurite via Command Palette: 'Azurite: Start' or use the status bar"

# Note: pre-commit is installed via Dev Container Feature
# Verify pre-commit is available
if ! command -v pre-commit &> /dev/null; then
    echo "ERROR: pre-commit not found. The feature may not have installed correctly."
    exit 1
fi

# Install pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install
pre-commit install --hook-type pre-push

# Install PowerShell modules from requirements.psd1
echo "Installing PowerShell modules..."
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
if [ -f "${WORKSPACE_DIR}/requirements.psd1" ]; then
    # shellcheck disable=SC2016
    pwsh -NoProfile -Command '
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Host "Loading module requirements from requirements.psd1..."

        $requirements = Import-PowerShellDataFile "'"${WORKSPACE_DIR}"'/requirements.psd1"
        $totalModules = $requirements.Count
        $current = 0

        foreach ($module in $requirements.GetEnumerator()) {
            $current++
            Write-Host "[$current/$totalModules] Installing $($module.Key)..." -ForegroundColor Cyan

            $installParams = @{
                Name       = $module.Key
                Repository = "PSGallery"
                Force      = $true
                Scope      = "CurrentUser"
            }

            if ($module.Value -is [hashtable]) {
                if ($module.Value.Version) {
                    $installParams["MinimumVersion"] = $module.Value.Version
                }
                if ($module.Value.MaximumVersion) {
                    $installParams["MaximumVersion"] = $module.Value.MaximumVersion
                }
            } else {
                $installParams["MinimumVersion"] = $module.Value
            }

            # Add AllowClobber for Az modules
            if ($module.Key -like "Az.*") {
                $installParams["AllowClobber"] = $true
            }

            try {
                Install-Module @installParams -ErrorAction Stop
                Write-Host "  ✓ $($module.Key) installed successfully" -ForegroundColor Green
            } catch {
                Write-Warning "  ✗ Failed to install $($module.Key): $_"
            }
        }

        Write-Host ""
        Write-Host "PowerShell modules installation complete!" -ForegroundColor Green
        Write-Host "Installed modules:" -ForegroundColor Cyan
        Get-InstalledModule | Where-Object { $requirements.ContainsKey($_.Name) } | Format-Table Name, Version -AutoSize
    '
else
    echo "⚠️  requirements.psd1 not found, skipping PowerShell module installation"
fi

# Install PowerShell profile with Git and Azure subscription display
echo "Installing PowerShell profile..."
mkdir -p ~/.config/powershell
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
if [ -f "${WORKSPACE_DIR}/.devcontainer/profile.ps1" ]; then
    cp "${WORKSPACE_DIR}/.devcontainer/profile.ps1" ~/.config/powershell/Microsoft.PowerShell_profile.ps1
    echo "✅ PowerShell profile installed"
else
    echo "⚠️  PowerShell profile not found, skipping"
fi

# Create local.settings.json if it doesn't exist
if [ ! -f "src/local.settings.json" ]; then
    echo "Creating local.settings.json from template..."
    cp src/local.settings.json.template src/local.settings.json
    echo "✅ Created src/local.settings.json - Please update with your Azure subscription ID"
else
    echo "✅ src/local.settings.json already exists"
fi

echo "=================================="
echo "DevContainer setup complete! 🎉"
echo "=================================="
echo ""
echo "Pre-commit hooks are installed and will run automatically on commits."
echo "To skip pre-commit hooks: git commit --no-verify"
echo "To run hooks manually: pre-commit run --all-files"
echo ""
echo "Next steps:"
echo "1. Start Azurite: Command Palette > 'Azurite: Start' or click status bar"
echo "2. Update src/local.settings.json with your Azure subscription ID"
echo "3. Authenticate with Azure: az login"
echo "4. Start the function app: func start --script-root src"
echo ""
