#!/usr/bin/env bash

# Install ACE and azure-cost-cli for cost estimation/analysis steps.

set -euo pipefail

ACE_VERSION="${ACE_VERSION:-1.6.4}"
AZURE_COST_VERSION="${AZURE_COST_VERSION:-0.52.0}"

echo "💰 Installing cost estimation tools..."

echo "📦 Installing ACE (Azure Cost Estimator) v${ACE_VERSION}..."
wget -q "https://github.com/TheCloudTheory/arm-estimator/releases/download/${ACE_VERSION}/linux-x64.zip" -O /tmp/ace.zip
unzip -q /tmp/ace.zip -d /tmp/ace
chmod +x /tmp/ace/azure-cost-estimator
/tmp/ace/azure-cost-estimator --version
echo "✅ ACE installed successfully"

echo "📦 Installing azure-cost-cli v${AZURE_COST_VERSION}..."
dotnet tool install --global azure-cost-cli --version "${AZURE_COST_VERSION}" \
  || dotnet tool update --global azure-cost-cli --version "${AZURE_COST_VERSION}"

# Ensure dotnet tools are in PATH for subsequent steps
if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$HOME/.dotnet/tools" >>"$GITHUB_PATH"
fi
export PATH="$HOME/.dotnet/tools:$PATH"

echo "✅ azure-cost-cli installed successfully"
