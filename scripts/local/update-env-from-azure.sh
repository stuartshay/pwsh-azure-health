#!/bin/bash
#
# Populate .env file with Azure CLI values
# Usage: ./scripts/local/update-env-from-azure.sh
#

set -e

ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found"
    echo "Run: cp .env.template .env"
    exit 1
fi

echo "Checking Azure CLI authentication..."

if ! az account show &> /dev/null; then
    echo "Error: Not logged in to Azure CLI"
    echo "Run: az login"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo "✓ Found Azure account"
echo "  Subscription: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo "  Tenant: $TENANT_ID"
echo ""

# Update AZURE_SUBSCRIPTION_ID if empty
if grep -q "^AZURE_SUBSCRIPTION_ID=\s*$" "$ENV_FILE"; then
    sed -i.bak "s|^AZURE_SUBSCRIPTION_ID=.*|AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    echo "✓ Updated AZURE_SUBSCRIPTION_ID"
elif grep -q "^AZURE_SUBSCRIPTION_ID=$" "$ENV_FILE"; then
    sed -i.bak "s|^AZURE_SUBSCRIPTION_ID=$|AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    echo "✓ Updated AZURE_SUBSCRIPTION_ID"
else
    echo "○ AZURE_SUBSCRIPTION_ID already set"
fi

# Update AZURE_TENANT_ID if empty
if grep -q "^AZURE_TENANT_ID=\s*$" "$ENV_FILE"; then
    sed -i.bak "s|^AZURE_TENANT_ID=.*|AZURE_TENANT_ID=$TENANT_ID|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    echo "✓ Updated AZURE_TENANT_ID"
elif grep -q "^AZURE_TENANT_ID=$" "$ENV_FILE"; then
    sed -i.bak "s|^AZURE_TENANT_ID=$|AZURE_TENANT_ID=$TENANT_ID|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
    echo "✓ Updated AZURE_TENANT_ID"
else
    echo "○ AZURE_TENANT_ID already set"
fi

echo ""
echo "✓ .env file updated successfully"
echo ""
echo "Next steps:"
echo "  1. Review and update other variables in .env as needed"
echo "  2. Ensure Azurite is running for local development"
echo "  3. Start the Function App with: func start"
