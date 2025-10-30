#!/bin/bash
# Manual installation script for development tools
# Use this if post-create.sh fails or to reinstall tools
# Note: Azure Functions Core Tools is installed via DevContainer Feature
# Note: Azurite is installed via VS Code extension (azurite.azurite)

set -e

echo "=================================="
echo "Checking Development Tools"
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

# Check Azurite extension
echo "Checking Azurite..."
echo "ℹ️  Azurite is managed via VS Code extension (azurite.azurite)"
echo "   Start it via: Command Palette > 'Azurite: Start'"
echo "   Or click the Azurite icon in the VS Code status bar"
echo ""

echo "=================================="
echo "Tool check complete!"
echo "=================================="
echo ""
