#!/bin/bash
# Installs PowerShell 7 on Debian/Ubuntu environments.
# Intended for local development containers or CI runners where pwsh is missing.

set -euo pipefail

if command -v pwsh >/dev/null 2>&1; then
    echo "✅ PowerShell already installed: $(pwsh -NoLogo -Command '$PSVersionTable.PSVersion.ToString()')"
    exit 0
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "❌ sudo is required to install PowerShell."
    exit 1
fi

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

package_uri="https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb"
package_path="$work_dir/packages-microsoft-prod.deb"

echo "⬇️  Downloading Microsoft package feed..."
wget -qO "$package_path" "$package_uri"

echo "📦 Registering package feed..."
sudo dpkg -i "$package_path"

echo "🔄 Updating package cache..."
sudo apt-get update

echo "⬇️  Installing PowerShell..."
sudo apt-get install -y powershell

echo "✅ PowerShell installation complete. Version: $(pwsh -NoLogo -Command '$PSVersionTable.PSVersion.ToString()')"
