#!/bin/bash

################################################################################
# Setup Script for GitHub Actions Azure Authentication
#
# This script automates the setup of Azure AD application and federated
# credentials for GitHub Actions OIDC authentication.
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - jq installed for JSON parsing
# - Appropriate Azure permissions (Owner or User Access Administrator)
#
# Usage:
#   ./setup-github-actions-azure.sh [OPTIONS]
#
# Options:
#   -o, --org GITHUB_ORG         GitHub organization (default: stuartshay)
#   -r, --repo GITHUB_REPO       GitHub repository (default: pwsh-azure-health)
#   -a, --app APP_NAME           Azure AD app name (default: github-pwsh-azure-health)
#   -s, --scope SCOPE            Permission scope: 'subscription' or 'resourcegroup' (default: subscription)
#   -h, --help                   Display this help message
#
# Example:
#   ./setup-github-actions-azure.sh
#   ./setup-github-actions-azure.sh --scope resourcegroup
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
GITHUB_ORG="stuartshay"
GITHUB_REPO="pwsh-azure-health"
APP_NAME="github-pwsh-azure-health"
PERMISSION_SCOPE="subscription"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--org)
      GITHUB_ORG="$2"
      shift 2
      ;;
    -r|--repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    -a|--app)
      APP_NAME="$2"
      shift 2
      ;;
    -s|--scope)
      PERMISSION_SCOPE="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,28p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Validate permission scope
if [[ "$PERMISSION_SCOPE" != "subscription" && "$PERMISSION_SCOPE" != "resourcegroup" ]]; then
  echo -e "${RED}Error: Invalid scope '$PERMISSION_SCOPE'. Must be 'subscription' or 'resourcegroup'${NC}"
  exit 1
fi

# Function to print section headers
print_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Function to print success messages
print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Function to print warning messages
print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error messages
print_error() {
  echo -e "${RED}❌ $1${NC}"
}

# Function to print info messages
print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
print_header "Checking Prerequisites"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
  print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi
print_success "Azure CLI is installed"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  print_warning "jq is not installed. Some features may not work properly."
  print_info "Install jq: https://stedolan.github.io/jq/download/"
fi

# Check if user is logged in to Azure
if ! az account show &> /dev/null; then
  print_error "Not logged in to Azure. Please run 'az login' first"
  exit 1
fi
print_success "Logged in to Azure"

# Get Azure subscription and tenant info
print_header "Azure Configuration"

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)

echo "Subscription Name: $SUBSCRIPTION_NAME"
echo "Subscription ID:   $SUBSCRIPTION_ID"
echo "Tenant ID:         $TENANT_ID"
echo ""
echo "GitHub Org:        $GITHUB_ORG"
echo "GitHub Repo:       $GITHUB_REPO"
echo "App Name:          $APP_NAME"
echo "Permission Scope:  $PERMISSION_SCOPE"

# Confirm before proceeding
echo ""
read -p "Continue with these settings? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  print_warning "Setup cancelled"
  exit 0
fi

# Step 1: Create Azure AD Application
print_header "Step 1: Creating Azure AD Application"

# Check if app already exists
EXISTING_APP=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || true)

if [ -n "$EXISTING_APP" ]; then
  print_warning "Application '$APP_NAME' already exists with ID: $EXISTING_APP"
  read -p "Do you want to use the existing application? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    APP_ID="$EXISTING_APP"
    print_info "Using existing application"
  else
    print_error "Please delete the existing application or choose a different name"
    exit 1
  fi
else
  az ad app create --display-name "$APP_NAME" > /dev/null
  APP_ID=$(az ad app list --display-name "$APP_NAME" --query [0].appId -o tsv)
  print_success "Created Azure AD application: $APP_NAME"
fi

echo "Application ID: $APP_ID"

# Step 2: Create Service Principal
print_header "Step 2: Creating Service Principal"

# Check if service principal exists
if az ad sp show --id "$APP_ID" &> /dev/null; then
  print_info "Service principal already exists"
else
  az ad sp create --id "$APP_ID" > /dev/null
  print_success "Created service principal"
fi

# Step 3: Configure Federated Credentials
print_header "Step 3: Configuring Federated Credentials"

# Function to detect the default branch name
detect_default_branch() {
  local default_branch
  default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
  if [ -z "$default_branch" ]; then
    # Fallback to master if detection fails
    default_branch="master"
  fi
  echo "$default_branch"
}

# Function to create federated credentials
create_federated_credential() {
  local cred_name="$1"
  local subject="$2"
  local description="$3"

  # Check if credential already exists
  if az ad app federated-credential show --id "$APP_ID" --federated-credential-id "$cred_name" &> /dev/null; then
    print_info "Federated credential '$cred_name' already exists - skipping"
  else
    az ad app federated-credential create \
      --id "$APP_ID" \
      --parameters "{
        \"name\": \"$cred_name\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"$subject\",
        \"audiences\": [\"api://AzureADTokenExchange\"],
        \"description\": \"$description\"
      }" > /dev/null
    print_success "Created federated credential: $cred_name"
  fi
}

# Detect the default branch name
DEFAULT_BRANCH=$(detect_default_branch)
print_info "Detected default branch: $DEFAULT_BRANCH"

# Create credentials for different contexts
create_federated_credential \
  "github-pwsh-azure-health-${DEFAULT_BRANCH}" \
  "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/${DEFAULT_BRANCH}" \
  "GitHub Actions - ${DEFAULT_BRANCH} branch"

create_federated_credential \
  "github-pwsh-azure-health-develop" \
  "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/develop" \
  "GitHub Actions - develop branch"

create_federated_credential \
  "github-pwsh-azure-health-pr" \
  "repo:$GITHUB_ORG/$GITHUB_REPO:pull_request" \
  "GitHub Actions - pull requests"

create_federated_credential \
  "github-pwsh-azure-health-env-dev" \
  "repo:$GITHUB_ORG/$GITHUB_REPO:environment:dev" \
  "GitHub Actions - dev environment"

create_federated_credential \
  "github-pwsh-azure-health-env-prod" \
  "repo:$GITHUB_ORG/$GITHUB_REPO:environment:prod" \
  "GitHub Actions - prod environment"

# Step 4: Assign Permissions
print_header "Step 4: Assigning Azure Permissions"

if [ "$PERMISSION_SCOPE" == "subscription" ]; then
  print_info "Assigning Contributor role at subscription level..."

  # Check if role assignment already exists
  if az role assignment list --assignee "$APP_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID" --query "[0].id" -o tsv | grep -q .; then
    print_info "Contributor role already assigned at subscription level"
  else
    az role assignment create \
      --assignee "$APP_ID" \
      --role "Contributor" \
      --scope "/subscriptions/$SUBSCRIPTION_ID" > /dev/null
    print_success "Assigned Contributor role at subscription level"
  fi
else
  print_info "Assigning Contributor role at resource group level..."

  # Create resource groups if they don't exist
  for ENV in dev prod; do
    RG_NAME="rg-azure-health-$ENV"

    if az group exists --name "$RG_NAME" | grep -q "true"; then
      print_info "Resource group '$RG_NAME' already exists"
    else
      az group create --name "$RG_NAME" --location eastus --tags environment="$ENV" project="azure-health" > /dev/null
      print_success "Created resource group: $RG_NAME"
    fi

    # Assign role
    if az role assignment list --assignee "$APP_ID" --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" --query "[0].id" -o tsv | grep -q .; then
      print_info "Contributor role already assigned to $RG_NAME"
    else
      az role assignment create \
        --assignee "$APP_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME" > /dev/null
      print_success "Assigned Contributor role to $RG_NAME"
    fi
  done
fi

# Step 5: Display GitHub Secrets Configuration
print_header "Step 5: GitHub Secrets Configuration"

echo "Add the following secrets to your GitHub repository:"
echo ""
echo "Repository: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "┌─────────────────────────────┬──────────────────────────────────────────┐"
echo "│ Secret Name                 │ Value                                    │"
echo "├─────────────────────────────┼──────────────────────────────────────────┤"
printf "│ %-27s │ %-40s │\n" "AZURE_CLIENT_ID" "$APP_ID"
printf "│ %-27s │ %-40s │\n" "AZURE_TENANT_ID" "$TENANT_ID"
printf "│ %-27s │ %-40s │\n" "AZURE_SUBSCRIPTION_ID" "$SUBSCRIPTION_ID"
echo "└─────────────────────────────┴──────────────────────────────────────────┘"
echo ""

# Check if GitHub CLI is available
if command -v gh &> /dev/null; then
  print_info "GitHub CLI detected"
  read -p "Do you want to automatically add secrets using GitHub CLI? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if authenticated
    if gh auth status &> /dev/null; then
      gh secret set AZURE_CLIENT_ID --body "$APP_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
      gh secret set AZURE_TENANT_ID --body "$TENANT_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
      gh secret set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
      print_success "GitHub secrets configured automatically"
    else
      print_warning "Not authenticated with GitHub CLI. Please run 'gh auth login' first"
      print_info "Or add secrets manually using the information above"
    fi
  else
    print_info "Please add the secrets manually using the information above"
  fi
else
  print_info "GitHub CLI not installed. Add secrets manually using the information above"
  print_info "Or install GitHub CLI: https://cli.github.com/"
fi

# Step 6: Verification
print_header "Step 6: Verification"

echo "Federated Credentials:"
az ad app federated-credential list --id "$APP_ID" --query "[].{Name:name, Subject:subject}" -o table

echo ""
echo "Role Assignments:"
az role assignment list --assignee "$APP_ID" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table

# Summary
print_header "Setup Complete!"

print_success "Azure AD application configured successfully"
print_success "Federated credentials created for GitHub Actions"
print_success "Azure permissions assigned"

echo ""
print_info "Next steps:"
echo "  1. Add the GitHub secrets shown above to your repository"
echo "  2. Test the setup by creating a PR that modifies infrastructure files"
echo "  3. Check the GitHub Actions workflow logs to verify authentication"
echo ""
print_info "For more information, see docs/GITHUB_ACTIONS_SETUP.md"
echo ""

# Save configuration to file
CONFIG_FILE="azure-github-actions-config.txt"
cat > "$CONFIG_FILE" << EOF
GitHub Actions Azure Configuration
===================================
Generated: $(date)

Azure Configuration:
  Subscription ID: $SUBSCRIPTION_ID
  Tenant ID: $TENANT_ID
  Application ID: $APP_ID
  Application Name: $APP_NAME
  Permission Scope: $PERMISSION_SCOPE

GitHub Configuration:
  Organization: $GITHUB_ORG
  Repository: $GITHUB_REPO

GitHub Secrets (add these to your repository):
  AZURE_CLIENT_ID: $APP_ID
  AZURE_TENANT_ID: $TENANT_ID
  AZURE_SUBSCRIPTION_ID: $SUBSCRIPTION_ID

Secrets URL: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions

Documentation: docs/GITHUB_ACTIONS_SETUP.md
EOF

print_success "Configuration saved to $CONFIG_FILE"
