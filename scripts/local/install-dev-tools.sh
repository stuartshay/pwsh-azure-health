#!/bin/bash
# Manual installation script for development tools
# Use this if post-create.sh fails or to reinstall tools

set -e

echo "=================================="
echo "Installing Development Tools"
echo "=================================="

# Check npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm not found. Please ensure Node.js is installed."
    exit 1
fi

echo "✅ npm version: $(npm --version)"
echo "✅ node version: $(node --version)"
echo ""

# Install Azure Functions Core Tools
echo "Installing Azure Functions Core Tools..."
if npm install -g azure-functions-core-tools@4; then
    echo "✅ Azure Functions Core Tools installed"
    func --version
else
    echo "❌ Failed to install Azure Functions Core Tools"
    echo "This may be due to network connectivity issues."
    echo "You can try again later or check: https://github.com/Azure/azure-functions-core-tools"
fi
echo ""

# Install Azurite
echo "Installing Azurite..."
if npm install -g azurite; then
    echo "✅ Azurite installed"
    azurite --version
else
    echo "❌ Failed to install Azurite"
    echo "You can try again later or check: https://github.com/Azure/Azurite"
fi
echo ""

echo "=================================="
echo "Installation complete!"
echo "=================================="
echo ""
echo "To start Azurite: ./scripts/local/start-azurite.sh"
echo "To start Functions: cd src && func start"
echo ""
