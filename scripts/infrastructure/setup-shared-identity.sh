#!/usr/bin/env bash
###############################################################################
# Setup Shared Azure Infrastructure for User-Assigned Managed Identity
#
# This script creates rg-azure-health-shared resource group and
# User-Assigned Managed Identity that can be shared across multiple projects
# (pwsh-azure-health, ts-azure-health).
#
# USAGE:
#   ./setup-shared-identity.sh
#   ./setup-shared-identity.sh --location westus2 --whatif
#
# NOTES:
#   - This resource group should NEVER be deleted
#   - Multiple projects depend on these resources
#   - Designed to be moved to separate rg-azure-health-shared repository
###############################################################################

set -euo pipefail

# Default configuration
LOCATION="${LOCATION:-eastus}"
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
WHAT_IF=false

# Shared resource configuration
SHARED_RG="rg-azure-health-shared"
MANAGED_IDENTITY_NAME="id-azurehealth-shared"
PROJECT_TAG="azure-health-monitoring"
LOCK_NAME="DoNotDelete-SharedInfrastructure"

# Color codes for output
RESET="\033[0m"
CYAN="\033[0;36m"
GRAY="\033[0;90m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"

###############################################################################
# Helper Functions
###############################################################################

print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${RESET}"
}

print_header() {
    echo ""
    print_message "$CYAN" "==========================================================="
    print_message "$CYAN" "$1"
    print_message "$CYAN" "==========================================================="
    echo ""
}

print_error() {
    echo ""
    print_message "$RED" "==========================================================="
    print_message "$RED" "  Setup Failed!"
    print_message "$RED" "==========================================================="
    echo ""
    print_message "$RED" "Error: $1"
    echo ""
    exit 1
}

###############################################################################
# Parse Arguments
###############################################################################

while [[ $# -gt 0 ]]; do
    case $1 in
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --subscription-id)
            SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        --whatif)
            WHAT_IF=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --location <location>           Azure region (default: eastus)"
            echo "  --subscription-id <id>          Azure subscription ID (default: current)"
            echo "  --whatif                        Preview changes without creating resources"
            echo "  --help                          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

###############################################################################
# Main Execution
###############################################################################

print_header "  Azure Health Monitoring - Shared Infrastructure Setup"

print_message "$YELLOW" "⚠️  WARNING: This creates PERMANENT shared infrastructure"
print_message "$YELLOW" "   Multiple projects depend on these resources!"
echo ""

print_message "$CYAN" "Configuration:"
print_message "$GRAY" "  Resource Group     : $SHARED_RG"
print_message "$GRAY" "  Managed Identity   : $MANAGED_IDENTITY_NAME"
print_message "$GRAY" "  Location           : $LOCATION"
print_message "$GRAY" "  Project Tag        : $PROJECT_TAG"
if [ "$WHAT_IF" = true ]; then
    print_message "$YELLOW" "  Mode               : What-If (preview only)"
fi
echo ""

# Check authentication
print_message "$CYAN" "Checking Azure CLI authentication..."
if ! az account show &>/dev/null; then
    print_error "Not logged in to Azure. Run: az login"
fi

if [ -z "$SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

ACCOUNT_NAME=$(az account show --query name -o tsv)
USER_NAME=$(az account show --query user.name -o tsv)

print_message "$GREEN" "[OK] Authenticated as: $USER_NAME"
print_message "$GRAY" "  Subscription: $ACCOUNT_NAME"
print_message "$GRAY" "  Subscription ID: $SUBSCRIPTION_ID"
echo ""

# What-If mode
if [ "$WHAT_IF" = true ]; then
    print_message "$YELLOW" "WHAT-IF MODE: The following actions would be performed:"
    echo ""
    print_message "$GRAY" "1. Create/verify resource group: $SHARED_RG"
    print_message "$GRAY" "2. Create User-Assigned Managed Identity: $MANAGED_IDENTITY_NAME"
    print_message "$GRAY" "3. Assign RBAC roles at subscription scope:"
    print_message "$GRAY" "   - Reader (for Service Health queries)"
    print_message "$GRAY" "   - Monitoring Reader (for monitoring data)"
    print_message "$GRAY" "4. Apply resource lock: $LOCK_NAME (CanNotDelete)"
    echo ""
    print_message "$YELLOW" "No changes will be made. Remove --whatif to execute."
    exit 0
fi

# Check if resource group exists
print_message "$CYAN" "Checking if shared resource group exists..."
if az group exists --name "$SHARED_RG" --output tsv | grep -q true; then
    print_message "$GREEN" "[OK] Resource group exists: $SHARED_RG"

    # Show existing resources
    EXISTING_COUNT=$(az resource list --resource-group "$SHARED_RG" --query 'length(@)' -o tsv)
    if [ "$EXISTING_COUNT" -gt 0 ]; then
        echo ""
        print_message "$CYAN" "Existing resources in shared resource group:"
        az resource list --resource-group "$SHARED_RG" --query '[].{Name:name, Type:type}' -o tsv | \
            while IFS=$'\t' read -r name type; do
                print_message "$GRAY" "  - $name ($type)"
            done
    fi
else
    print_message "$CYAN" "Creating shared resource group..."
    az group create \
        --name "$SHARED_RG" \
        --location "$LOCATION" \
        --tags \
            purpose=shared-infrastructure \
            lifecycle=permanent \
            project="$PROJECT_TAG" \
            sharedBy=pwsh-azure-health,ts-azure-health \
        --output none

    print_message "$GREEN" "[OK] Created resource group: $SHARED_RG"
fi
echo ""

# Check if managed identity exists
print_message "$CYAN" "Checking if User-Assigned Managed Identity exists..."
if IDENTITY_JSON=$(az identity show \
    --name "$MANAGED_IDENTITY_NAME" \
    --resource-group "$SHARED_RG" \
    2>/dev/null); then

    PRINCIPAL_ID=$(echo "$IDENTITY_JSON" | jq -r '.principalId')
    CLIENT_ID=$(echo "$IDENTITY_JSON" | jq -r '.clientId')
    RESOURCE_ID=$(echo "$IDENTITY_JSON" | jq -r '.id')

    print_message "$GREEN" "[OK] Managed Identity already exists"
    print_message "$GRAY" "  Name        : $MANAGED_IDENTITY_NAME"
    print_message "$GRAY" "  Principal ID: $PRINCIPAL_ID"
    print_message "$GRAY" "  Client ID   : $CLIENT_ID"
    print_message "$GRAY" "  Resource ID : $RESOURCE_ID"
else
    print_message "$CYAN" "Creating User-Assigned Managed Identity..."
    IDENTITY_JSON=$(az identity create \
        --name "$MANAGED_IDENTITY_NAME" \
        --resource-group "$SHARED_RG" \
        --location "$LOCATION" \
        --tags \
            purpose=shared-identity \
            lifecycle=permanent \
            project="$PROJECT_TAG" \
            usedBy=pwsh-azure-health,ts-azure-health)

    PRINCIPAL_ID=$(echo "$IDENTITY_JSON" | jq -r '.principalId')
    CLIENT_ID=$(echo "$IDENTITY_JSON" | jq -r '.clientId')
    RESOURCE_ID=$(echo "$IDENTITY_JSON" | jq -r '.id')

    print_message "$GREEN" "[OK] Created Managed Identity: $MANAGED_IDENTITY_NAME"
    print_message "$GRAY" "  Principal ID: $PRINCIPAL_ID"
    print_message "$GRAY" "  Client ID   : $CLIENT_ID"
    print_message "$GRAY" "  Resource ID : $RESOURCE_ID"

    # Wait for identity propagation
    echo ""
    print_message "$CYAN" "Waiting for identity propagation (30 seconds)..."
    sleep 30
fi
echo ""

# Assign Reader role at subscription scope
print_message "$CYAN" "Assigning RBAC roles at subscription scope..."
print_message "$GRAY" "  Role: Reader (for Service Health queries)"

if az role assignment list \
    --assignee "$PRINCIPAL_ID" \
    --role Reader \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --query '[0].id' -o tsv | grep -q .; then
    print_message "$YELLOW" "  [SKIP] Reader role already assigned"
else
    az role assignment create \
        --assignee "$PRINCIPAL_ID" \
        --role Reader \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --output none
    print_message "$GREEN" "  [OK] Reader role assigned"
fi

# Assign Monitoring Reader role at subscription scope
print_message "$GRAY" "  Role: Monitoring Reader (for monitoring data)"

if az role assignment list \
    --assignee "$PRINCIPAL_ID" \
    --role "Monitoring Reader" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --query '[0].id' -o tsv | grep -q .; then
    print_message "$YELLOW" "  [SKIP] Monitoring Reader role already assigned"
else
    az role assignment create \
        --assignee "$PRINCIPAL_ID" \
        --role "Monitoring Reader" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --output none
    print_message "$GREEN" "  [OK] Monitoring Reader role assigned"
fi
echo ""

# Apply resource lock to prevent accidental deletion
print_message "$CYAN" "Applying resource lock to prevent accidental deletion..."
if az lock list \
    --resource-group "$SHARED_RG" \
    --query "[?name=='$LOCK_NAME'].id" -o tsv | grep -q .; then
    print_message "$YELLOW" "  [SKIP] Lock already exists: $LOCK_NAME"
else
    az lock create \
        --name "$LOCK_NAME" \
        --resource-group "$SHARED_RG" \
        --lock-type CanNotDelete \
        --notes "Prevents accidental deletion of shared infrastructure used by multiple projects" \
        --output none
    print_message "$GREEN" "  [OK] Applied lock: $LOCK_NAME"
fi
echo ""

# Save identity information to file for reference
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="$SCRIPT_DIR/shared-identity-info.json"

cat > "$OUTPUT_FILE" <<EOF
{
  "resourceGroup": "$SHARED_RG",
  "identityName": "$MANAGED_IDENTITY_NAME",
  "principalId": "$PRINCIPAL_ID",
  "clientId": "$CLIENT_ID",
  "resourceId": "$RESOURCE_ID",
  "location": "$LOCATION",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "createdDate": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

print_message "$CYAN" "Identity information saved to: $OUTPUT_FILE"
echo ""

# Display summary
print_header "  Setup Complete!"

print_message "$CYAN" "Shared Infrastructure Summary:"
print_message "$GRAY" "  Resource Group      : $SHARED_RG"
print_message "$GRAY" "  Managed Identity    : $MANAGED_IDENTITY_NAME"
print_message "$GRAY" "  Principal ID        : $PRINCIPAL_ID"
print_message "$GRAY" "  Client ID           : $CLIENT_ID"
print_message "$GRAY" "  Resource ID         : $RESOURCE_ID"
print_message "$GRAY" "  Resource Lock       : $LOCK_NAME (CanNotDelete)"
echo ""

print_message "$CYAN" "RBAC Assignments:"
print_message "$GRAY" "  ✓ Reader (subscription scope)"
print_message "$GRAY" "  ✓ Monitoring Reader (subscription scope)"
echo ""

print_message "$CYAN" "Next Steps:"
print_message "$GRAY" "  1. Use this Managed Identity in your project deployments"
print_message "$YELLOW" "     Identity Resource ID: $RESOURCE_ID"
echo ""
print_message "$GRAY" "  2. For pwsh-azure-health deployment:"
print_message "$GRAY" "     Update infrastructure/main.bicepparam with:"
print_message "$YELLOW" "     param managedIdentityResourceId = '$RESOURCE_ID'"
echo ""
print_message "$GRAY" "  3. For storage access, assign Storage Blob Data Contributor:"
print_message "$YELLOW" "     az role assignment create \\"
print_message "$YELLOW" "       --assignee $PRINCIPAL_ID \\"
print_message "$YELLOW" "       --role \"Storage Blob Data Contributor\" \\"
print_message "$YELLOW" "       --scope /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{storage}"
echo ""

print_message "$YELLOW" "⚠️  IMPORTANT: This resource group should NEVER be deleted!"
print_message "$YELLOW" "   Multiple projects depend on this infrastructure."
echo ""
