#!/bin/bash
set -e

echo "=================================="
echo "Setting up DevContainer environment..."
echo "=================================="

# Install Azure Functions Core Tools via npm
echo "Installing Azure Functions Core Tools..."
sudo npm install -g azure-functions-core-tools@4 --unsafe-perm true

# Verify tools are installed
echo "Verifying installed tools..."
pwsh --version
func --version
dotnet --version
az version

# Install pre-commit framework
echo "Installing pre-commit..."
pip3 install --user pre-commit
export PATH="$HOME/.local/bin:$PATH"

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
