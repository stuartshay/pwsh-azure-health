#!/bin/bash
set -e

echo "=================================="
echo "Setting up DevContainer environment..."
echo "=================================="

# Verify tools are installed
echo "Verifying installed tools..."
pwsh --version
func --version
dotnet --version
az version

# Install PowerShell modules
echo "Installing PowerShell modules..."
pwsh -Command "
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name Az -Repository PSGallery -Force -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue
    Install-Module -Name Az.ResourceGraph -Repository PSGallery -Force -Scope CurrentUser -ErrorAction SilentlyContinue
    Install-Module -Name Az.Monitor -Repository PSGallery -Force -Scope CurrentUser -ErrorAction SilentlyContinue
    Install-Module -Name Pester -Repository PSGallery -Force -Scope CurrentUser -MinimumVersion 5.0 -ErrorAction SilentlyContinue
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
echo "Next steps:"
echo "1. Update src/local.settings.json with your Azure subscription ID"
echo "2. Authenticate with Azure: az login"
echo "3. Start the function app: func start --script-root src"
echo ""
