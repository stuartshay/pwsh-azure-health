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

# Wait for nvm to be available (features may still be initializing)
echo "Waiting for Node.js installation to complete..."
sleep 5

# Find and set nvm/node paths
if [ -d "/usr/local/share/nvm" ]; then
    export NVM_DIR="/usr/local/share/nvm"
    # Source nvm if available
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

# Install Azurite for local Azure Storage emulation
echo "Installing Azurite..."
if sudo -E env PATH="$PATH" "$NPM_PATH" install -g azurite; then
    echo "✅ Azurite installed successfully"
else
    echo "❌ Failed to install Azurite"
    echo "You can install it manually later: npm install -g azurite"
fi

# Start Azurite in the background
echo "Starting Azurite..."
mkdir -p /workspaces/pwsh-azure-health/.azurite
if command -v azurite &> /dev/null; then
    azurite --silent --location /workspaces/pwsh-azure-health/.azurite --debug /workspaces/pwsh-azure-health/.azurite/debug.log &
    echo "✅ Azurite started on ports 10000 (Blob), 10001 (Queue), 10002 (Table)"
else
    echo "⚠️  Azurite not available, skipping auto-start"
    echo "You can start it manually later: ./scripts/local/start-azurite.sh"
fi

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

# Install PowerShell modules
echo "Installing PowerShell modules..."
pwsh -Command "
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Write-Host 'Installing Az module...'
    Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -MinimumVersion 14.0.0
    Write-Host 'Installing Az.ResourceGraph module...'
    Install-Module -Name Az.ResourceGraph -Repository PSGallery -Force -Scope CurrentUser
    Write-Host 'Installing Az.Monitor module...'
    Install-Module -Name Az.Monitor -Repository PSGallery -Force -Scope CurrentUser
    Write-Host 'Installing Pester module...'
    Install-Module -Name Pester -Repository PSGallery -Force -Scope CurrentUser -MinimumVersion 5.0.0 -MaximumVersion 5.99.99
    Write-Host 'Installing PSScriptAnalyzer module...'
    Install-Module -Name PSScriptAnalyzer -Repository PSGallery -Force -Scope CurrentUser
    Write-Host 'PowerShell modules installed successfully!'
"

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
echo "1. Update src/local.settings.json with your Azure subscription ID"
echo "2. Authenticate with Azure: az login"
echo "3. Start the function app: func start --script-root src"
echo ""
echo "If Azurite failed to install, you can retry with:"
echo "  npm install -g azurite"
echo ""
