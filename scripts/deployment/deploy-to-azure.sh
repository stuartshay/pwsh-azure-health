#!/bin/bash
#
# Deploy Azure Health Functions to Azure
#
# Usage: ./deploy-to-azure.sh [resource-group] [function-app-name]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Azure Health Functions Deployment Script${NC}"
echo ""

# Parse arguments or use defaults
RESOURCE_GROUP=${1:-"rg-azure-health"}
FUNCTION_APP=${2:-"func-azure-health-$(date +%s)"}
LOCATION=${3:-"eastus"}
STORAGE_ACCOUNT="st$(echo $FUNCTION_APP | tr -d '-')$(date +%s)"
APP_INSIGHTS="ai-azure-health"

echo -e "${YELLOW}Configuration:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Function App:   $FUNCTION_APP"
echo "  Location:       $LOCATION"
echo "  Storage:        $STORAGE_ACCOUNT"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}ERROR: Azure CLI is not installed${NC}"
    echo "Install from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in to Azure
echo -e "${YELLOW}Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}ERROR: Not logged in to Azure${NC}"
    echo "Run: az login"
    exit 1
fi
echo -e "${GREEN}✓ Authenticated${NC}"

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Using subscription: $SUBSCRIPTION_NAME${NC}"
echo ""

# Create resource group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output none
echo -e "${GREEN}✓ Resource group created${NC}"

# Create storage account
echo -e "${YELLOW}Creating storage account...${NC}"
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Standard_LRS \
  --output none
echo -e "${GREEN}✓ Storage account created${NC}"

# Create Application Insights
echo -e "${YELLOW}Creating Application Insights...${NC}"
az monitor app-insights component create \
  --app $APP_INSIGHTS \
  --location $LOCATION \
  --resource-group $RESOURCE_GROUP \
  --application-type web \
  --output none 2>/dev/null || echo -e "${YELLOW}  Application Insights may already exist${NC}"
echo -e "${GREEN}✓ Application Insights ready${NC}"

# Get Application Insights connection string
AI_CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

# Create Function App
echo -e "${YELLOW}Creating Function App...${NC}"
az functionapp create \
  --resource-group $RESOURCE_GROUP \
  --consumption-plan-location $LOCATION \
  --runtime powershell \
  --runtime-version 7.4 \
  --functions-version 4 \
  --name $FUNCTION_APP \
  --storage-account $STORAGE_ACCOUNT \
  --app-insights $APP_INSIGHTS \
  --output none
echo -e "${GREEN}✓ Function App created${NC}"

# Configure application settings
echo -e "${YELLOW}Configuring application settings...${NC}"
az functionapp config appsettings set \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --settings \
    "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID" \
    "APPLICATIONINSIGHTS_CONNECTION_STRING=$AI_CONNECTION_STRING" \
  --output none
echo -e "${GREEN}✓ Application settings configured${NC}"

# Enable managed identity
echo -e "${YELLOW}Enabling managed identity...${NC}"
PRINCIPAL_ID=$(az functionapp identity assign \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)
echo -e "${GREEN}✓ Managed identity enabled${NC}"

# Assign Reader role
echo -e "${YELLOW}Assigning Azure roles...${NC}"
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --output none 2>/dev/null || echo -e "${YELLOW}  Reader role may already be assigned${NC}"

az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role "Monitoring Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --output none 2>/dev/null || echo -e "${YELLOW}  Monitoring Reader role may already be assigned${NC}"
echo -e "${GREEN}✓ Roles assigned${NC}"

# Deploy function code
echo -e "${YELLOW}Deploying function code...${NC}"
cd "$(dirname "$0")/../.."
func azure functionapp publish $FUNCTION_APP --script-root src
echo -e "${GREEN}✓ Function code deployed${NC}"

# Get function key
echo -e "${YELLOW}Retrieving function key...${NC}"
sleep 5  # Wait for deployment to complete
FUNCTION_KEY=$(az functionapp keys list \
  --name $FUNCTION_APP \
  --resource-group $RESOURCE_GROUP \
  --query functionKeys.default -o tsv 2>/dev/null || echo "")

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Function App URL: https://${FUNCTION_APP}.azurewebsites.net"
if [ -n "$FUNCTION_KEY" ]; then
    echo "Function Key: $FUNCTION_KEY"
    echo ""
    echo "Test with:"
    echo "  curl \"https://${FUNCTION_APP}.azurewebsites.net/api/GetServiceHealth?code=${FUNCTION_KEY}\""
fi
