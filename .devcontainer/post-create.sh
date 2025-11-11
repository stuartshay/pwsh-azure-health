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

# Ensure PowerShell is at the latest stable version
echo "Checking for newer PowerShell release..."
CURRENT_PWSH_VERSION=$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo "")
POWERSHELL_RELEASE_INFO=$(pwsh -NoProfile -Command "
    try {
        \$headers = @{ 'User-Agent' = 'pwsh-azure-health-devcontainer' }
        \$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -Headers \$headers
        if (-not \$release) { return }
        \$version = \$release.tag_name.TrimStart('v')
        \$asset = \$release.assets | Where-Object { \$_.name -match 'powershell_.*deb_amd64\.deb$' } | Select-Object -First 1
        if (-not \$asset) { return }
        Write-Output (\$version)
        Write-Output (\$asset.browser_download_url)
    }
    catch {
        # GitHub rate limits or network issues
    }
" 2>/dev/null) || POWERSHELL_RELEASE_INFO=""
LATEST_PWSH_VERSION=$(echo "$POWERSHELL_RELEASE_INFO" | sed -n '1p')
LATEST_PWSH_URL=$(echo "$POWERSHELL_RELEASE_INFO" | sed -n '2p')

if [ -n "$LATEST_PWSH_VERSION" ] && [ -n "$LATEST_PWSH_URL" ] && [ -n "$CURRENT_PWSH_VERSION" ]; then
    if dpkg --compare-versions "$LATEST_PWSH_VERSION" gt "$CURRENT_PWSH_VERSION"; then
        echo "Updating PowerShell from ${CURRENT_PWSH_VERSION:-unknown} to ${LATEST_PWSH_VERSION}..."
        TEMP_PWSH_DEB=$(mktemp /tmp/powershell-XXXXXX.deb)
        if curl -sSL "$LATEST_PWSH_URL" -o "$TEMP_PWSH_DEB"; then
            if sudo dpkg -i "$TEMP_PWSH_DEB"; then
                echo "✅ PowerShell updated to $LATEST_PWSH_VERSION"
            else
                echo "ℹ️  Resolving PowerShell package dependencies..."
                sudo apt-get update
                sudo apt-get install -y -f
                sudo dpkg -i "$TEMP_PWSH_DEB"
                echo "✅ PowerShell updated to $LATEST_PWSH_VERSION"
            fi
        else
            echo "⚠️  Failed to download PowerShell ${LATEST_PWSH_VERSION} package"
        fi
        rm -f "$TEMP_PWSH_DEB"
    else
        echo "✅ PowerShell $CURRENT_PWSH_VERSION is already the latest available build ($LATEST_PWSH_VERSION)"
    fi
else
    echo "⚠️  Unable to determine latest PowerShell release. Skipping upgrade."
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

# Install azure-cost-cli for cost analysis
echo "Installing azure-cost-cli..."
if command -v dotnet &> /dev/null; then
    if dotnet tool install --global azure-cost-cli --version 0.52.0 2>/dev/null || dotnet tool update --global azure-cost-cli --version 0.52.0 2>/dev/null; then
        echo "✅ azure-cost-cli installed successfully"
        # Ensure dotnet tools are in PATH
        export PATH="$PATH:$HOME/.dotnet/tools"
        if command -v azure-cost-cli &> /dev/null; then
            echo "✅ azure-cost-cli: $(azure-cost-cli --version 2>/dev/null || echo 'installed')"
        fi
    else
        echo "⚠️  azure-cost-cli installation may have failed"
    fi
else
    echo "⚠️  .NET SDK not found, skipping azure-cost-cli installation"
fi

# Note: Azurite is managed via VS Code extension (azurite.azurite)
# Create the workspace directory for Azurite data
echo "Creating Azurite workspace directory..."
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
mkdir -p "${WORKSPACE_DIR}/.azurite"
echo "✅ Azurite directory ready at ${WORKSPACE_DIR}/.azurite"
echo "ℹ️  Start Azurite via Command Palette: 'Azurite: Start' or use the status bar"

# Configure pre-commit to use a workspace-local cache so hooks can run without writing to the readonly home cache
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
PRE_COMMIT_CACHE_DIR="${WORKSPACE_DIR}/.pre-commit-cache"
mkdir -p "$PRE_COMMIT_CACHE_DIR"
if ! grep -q "PRE_COMMIT_HOME" "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ""
        echo "# Use repository-local cache for pre-commit to avoid readonly \$HOME/.cache"
        echo "export PRE_COMMIT_HOME=\"${PRE_COMMIT_CACHE_DIR}\""
    } >> "$HOME/.bashrc"
fi
export PRE_COMMIT_HOME="${PRE_COMMIT_CACHE_DIR}"

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
                if ($module.Value.MinimumVersion) {
                    $installParams["MinimumVersion"] = $module.Value.MinimumVersion
                }
                if ($module.Value.MaximumVersion) {
                    $installParams["MaximumVersion"] = $module.Value.MaximumVersion
                }
                # Legacy support for Version key
                if ($module.Value.Version -and -not $module.Value.MinimumVersion) {
                    $installParams["MinimumVersion"] = $module.Value.Version
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
