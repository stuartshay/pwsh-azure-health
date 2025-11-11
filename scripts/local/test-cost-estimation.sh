#!/bin/bash
#
# Test Cost Estimation Locally
# This script tests both ACE (pre-deployment estimation) and azure-cost-cli (actual costs)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INFRA_DIR="$WORKSPACE_ROOT/infrastructure"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${1:-dev}"
SKU="${2:-Y1}"
RESOURCE_GROUP="rg-azure-health-$ENVIRONMENT"
# shellcheck disable=SC2034  # LOCATION used in examples/documentation
LOCATION="eastus"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Azure Health Monitoring - Local Cost Estimation Test       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI (az) not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI${NC}"

if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ jq${NC}"

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure. Run 'az login' first${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Azure authentication${NC}"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}✅ Subscription: $SUBSCRIPTION_ID${NC}"
echo ""

# Install ACE if needed
if [ ! -f /tmp/ace-test/azure-cost-estimator ]; then
    echo -e "${YELLOW}📦 Installing ACE (Azure Cost Estimator)...${NC}"
    wget -q https://github.com/TheCloudTheory/arm-estimator/releases/download/1.6.4/linux-x64.zip -O /tmp/ace.zip
    mkdir -p /tmp/ace-test
    unzip -q /tmp/ace.zip -d /tmp/ace-test
    chmod +x /tmp/ace-test/azure-cost-estimator
    echo -e "${GREEN}✅ ACE installed${NC}"
else
    echo -e "${GREEN}✅ ACE already installed${NC}"
fi

# Check for azure-cost
if ! command -v azure-cost &> /dev/null; then
    echo -e "${YELLOW}📦 azure-cost-cli not found. Install with:${NC}"
    echo "   dotnet tool install --global azure-cost-cli"
    echo -e "${YELLOW}⏩ Skipping actual cost analysis...${NC}"
    SKIP_ACTUAL_COSTS=true
else
    echo -e "${GREEN}✅ azure-cost-cli${NC}"
    SKIP_ACTUAL_COSTS=false
fi
echo ""

# Get managed identity resource ID
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}1. Getting Managed Identity${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

SHARED_RG="rg-azure-health-shared"
IDENTITY_NAME="id-azurehealth-shared"

if ! az group show --name "$SHARED_RG" &> /dev/null; then
    echo -e "${RED}❌ Shared resource group not found: $SHARED_RG${NC}"
    echo "   Run: ./scripts/infrastructure/setup-shared-identity.ps1"
    exit 1
fi

MANAGED_IDENTITY_RESOURCE_ID=$(az identity show \
    --name "$IDENTITY_NAME" \
    --resource-group "$SHARED_RG" \
    --query id \
    --output tsv 2>/dev/null)

if [ -z "$MANAGED_IDENTITY_RESOURCE_ID" ]; then
    echo -e "${RED}❌ Managed identity not found: $IDENTITY_NAME${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Managed Identity: $MANAGED_IDENTITY_RESOURCE_ID${NC}"
echo ""

# Pre-deployment cost estimation
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}2. Pre-Deployment Cost Estimation (ACE)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

cd "$INFRA_DIR"

echo -e "${YELLOW}🔧 Transpiling Bicep to ARM template...${NC}"
az bicep build \
    --file main.bicep \
    --outfile /tmp/test-main.json

echo -e "${YELLOW}📊 Running ACE cost estimation...${NC}"
echo ""

/tmp/ace-test/azure-cost-estimator \
    /tmp/test-main.json \
    "$SUBSCRIPTION_ID" \
    "$RESOURCE_GROUP" \
    --inline "environment=$ENVIRONMENT" \
    --inline "functionAppPlanSku=$SKU" \
    --inline "managedIdentityResourceId=$MANAGED_IDENTITY_RESOURCE_ID" \
    --currency USD

echo ""
echo -e "${GREEN}✅ Cost estimation completed${NC}"
echo ""

# Actual cost analysis
if [ "$SKIP_ACTUAL_COSTS" = false ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}3. Actual Cost Analysis (azure-cost-cli)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

    if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
        echo -e "${YELLOW}💵 Querying actual costs for $RESOURCE_GROUP...${NC}"
        echo ""

        azure-cost \
            --subscription "$SUBSCRIPTION_ID" \
            --resource-group "$RESOURCE_GROUP" \
            --output Console \
            --timeframe MonthToDate || {
            echo -e "${YELLOW}⚠️  No cost data available yet (resources may be new)${NC}"
        }

        echo ""
        echo -e "${GREEN}✅ Actual cost analysis completed${NC}"
    else
        echo -e "${YELLOW}⚠️  Resource group doesn't exist yet: $RESOURCE_GROUP${NC}"
        echo "   Deploy infrastructure first to see actual costs"
    fi
else
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}3. Actual Cost Analysis${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⏩ Skipped (azure-cost-cli not installed)${NC}"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Complete!                                             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Usage:${NC}"
echo "  $0 [environment] [sku]"
echo ""
echo -e "${GREEN}Examples:${NC}"
echo "  $0              # dev environment, Y1 SKU"
echo "  $0 prod         # prod environment, Y1 SKU"
echo "  $0 dev EP1      # dev environment, EP1 (Premium) SKU"
echo ""
