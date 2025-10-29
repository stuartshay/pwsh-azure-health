#!/bin/bash
# Manual installation script for development tools
# Use this if post-create.sh fails or to reinstall tools
# Note: Azure Functions Core Tools is installed via DevContainer Feature

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

# Check Azure Functions Core Tools (should be from feature)
echo "Checking Azure Functions Core Tools..."
if command -v func &> /dev/null; then
    echo "✅ Azure Functions Core Tools already installed via feature"
    func --version
else
    echo "⚠️  Azure Functions Core Tools not found"
    echo "This should be installed via DevContainer Feature."
    echo "Try rebuilding the container: Dev Containers: Rebuild Container"
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
