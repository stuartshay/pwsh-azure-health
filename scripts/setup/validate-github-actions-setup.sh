#!/bin/bash

################################################################################
# GitHub Actions Azure Setup Validation Script
#
# This script validates that Azure AD application and GitHub secrets are
# configured correctly for GitHub Actions OIDC authentication.
#
# Prerequisites:
# - Azure CLI installed and authenticated (az login)
# - GitHub CLI installed (optional, for checking GitHub secrets)
#
# Usage:
#   ./validate-github-actions-setup.sh [OPTIONS]
#
# Options:
#   -o, --org GITHUB_ORG         GitHub organization (default: stuartshay)
#   -r, --repo GITHUB_REPO       GitHub repository (default: pwsh-azure-health)
#   -a, --app APP_NAME           Azure AD app name (default: github-pwsh-azure-health)
#   -h, --help                   Display this help message
#
################################################################################

set -e

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

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

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
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Function to print section headers
print_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""
}

# Function for check results
check_pass() {
  echo -e "${GREEN}✅ PASS:${NC} $1"
  ((CHECKS_PASSED++)) || true
}

check_fail() {
  echo -e "${RED}❌ FAIL:${NC} $1"
  ((CHECKS_FAILED++)) || true
}

check_warn() {
  echo -e "${YELLOW}⚠️  WARN:${NC} $1"
  ((CHECKS_WARNING++)) || true
}

print_info() {
  echo -e "${BLUE}ℹ️  $1${NC}"
}

# Start validation
print_header "GitHub Actions Azure Setup Validation"

echo "Repository: $GITHUB_ORG/$GITHUB_REPO"
echo "Azure AD App: $APP_NAME"
echo ""

# Check Azure CLI
print_header "1. Checking Prerequisites"

if command -v az &> /dev/null; then
  check_pass "Azure CLI is installed"
else
  check_fail "Azure CLI is not installed"
  exit 1
fi

if az account show &> /dev/null; then
  check_pass "Logged in to Azure"
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
  TENANT_ID=$(az account show --query tenantId -o tsv)
  echo "   Subscription: $SUBSCRIPTION_ID"
  echo "   Tenant: $TENANT_ID"
else
  check_fail "Not logged in to Azure"
  exit 1
fi

if command -v gh &> /dev/null; then
  check_pass "GitHub CLI is installed"
  GH_CLI_AVAILABLE=true
else
  check_warn "GitHub CLI is not installed (optional)"
  GH_CLI_AVAILABLE=false
fi

# Check Azure AD Application
print_header "2. Checking Azure AD Application"

APP_ID=$(az ad app list --display-name "$APP_NAME" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -n "$APP_ID" ]; then
  check_pass "Azure AD application '$APP_NAME' exists"
  echo "   Application ID: $APP_ID"
else
  check_fail "Azure AD application '$APP_NAME' not found"
  echo "   Run: ./setup-github-actions-azure.sh"
  exit 1
fi

# Check Service Principal
print_header "3. Checking Service Principal"

if az ad sp show --id "$APP_ID" &> /dev/null; then
  check_pass "Service principal exists"
else
  check_fail "Service principal not found"
  echo "   Run: az ad sp create --id $APP_ID"
fi

# Check Federated Credentials
print_header "4. Checking Federated Credentials"

# Detect the default branch name
detect_default_branch() {
  local default_branch
  default_branch=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5)
  if [ -z "$default_branch" ]; then
    # Fallback to master if detection fails
    default_branch="master"
  fi
  echo "$default_branch"
}

DEFAULT_BRANCH=$(detect_default_branch)
print_info "Checking for default branch: $DEFAULT_BRANCH"

REQUIRED_SUBJECTS=(
  "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$DEFAULT_BRANCH"
  "repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/develop"
  "repo:$GITHUB_ORG/$GITHUB_REPO:pull_request"
  "repo:$GITHUB_ORG/$GITHUB_REPO:environment:dev"
  "repo:$GITHUB_ORG/$GITHUB_REPO:environment:prod"
)

CREDS=$(az ad app federated-credential list --id "$APP_ID" --query "[].subject" -o tsv 2>/dev/null || echo "")

for subject in "${REQUIRED_SUBJECTS[@]}"; do
  if echo "$CREDS" | grep -q "$subject"; then
    check_pass "Federated credential configured for: $subject"
  else
    check_fail "Missing federated credential for: $subject"
  fi
done

# Check Role Assignments
print_header "5. Checking Azure Role Assignments"

ROLES=$(az role assignment list --assignee "$APP_ID" --query "[].{Role:roleDefinitionName, Scope:scope}" -o tsv 2>/dev/null || echo "")

if [ -n "$ROLES" ]; then
  if echo "$ROLES" | grep -q "Contributor"; then
    check_pass "Contributor role is assigned"
    echo ""
    echo "Role Assignments:"
    az role assignment list --assignee "$APP_ID" --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
  else
    check_fail "Contributor role not assigned"
  fi
else
  check_fail "No role assignments found"
fi

# Check GitHub Secrets
print_header "6. Checking GitHub Secrets"

if [ "$GH_CLI_AVAILABLE" = true ] && gh auth status &> /dev/null; then
  SECRETS=$(gh secret list --repo "$GITHUB_ORG/$GITHUB_REPO" 2>/dev/null || echo "")

  if [ -n "$SECRETS" ]; then
    # Check required secrets
    for secret in "AZURE_CLIENT_ID" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID"; do
      if echo "$SECRETS" | grep -q "$secret"; then
        check_pass "GitHub secret '$secret' is configured"
      else
        check_fail "GitHub secret '$secret' is missing"
      fi
    done
  else
    check_warn "Could not retrieve GitHub secrets list"
  fi
else
  check_warn "Cannot check GitHub secrets (GitHub CLI not available or not authenticated)"
  print_info "Manually verify secrets at: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
fi

# Check GitHub Variables
print_header "7. Checking GitHub Variables"

if [ "$GH_CLI_AVAILABLE" = true ] && gh auth status &> /dev/null; then
  VARIABLES=$(gh variable list --repo "$GITHUB_ORG/$GITHUB_REPO" 2>/dev/null || echo "")

  if [ -n "$VARIABLES" ]; then
    if echo "$VARIABLES" | grep -q "MANAGED_IDENTITY_RESOURCE_ID"; then
      check_pass "GitHub variable 'MANAGED_IDENTITY_RESOURCE_ID' is configured"
      MANAGED_IDENTITY_ID=$(gh variable get MANAGED_IDENTITY_RESOURCE_ID --repo "$GITHUB_ORG/$GITHUB_REPO" 2>/dev/null)
      if [ -n "$MANAGED_IDENTITY_ID" ]; then
        echo "   Resource ID: $MANAGED_IDENTITY_ID"
      fi
    else
      check_warn "GitHub variable 'MANAGED_IDENTITY_RESOURCE_ID' not set (workflows will fall back to local file)"
      print_info "To set: gh variable set MANAGED_IDENTITY_RESOURCE_ID --body '<resource-id>'"
    fi
  else
    check_warn "Could not retrieve GitHub variables list"
  fi
else
  check_warn "Cannot check GitHub variables (GitHub CLI not available or not authenticated)"
  print_info "Manually verify variables at: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/variables/actions"
fi

# Check GitHub Environments
print_header "8. Checking GitHub Environments (Optional)"

if [ "$GH_CLI_AVAILABLE" = true ] && gh auth status &> /dev/null; then
  for env in "dev" "prod"; do
    if gh api "repos/$GITHUB_ORG/$GITHUB_REPO/environments/$env" &> /dev/null; then
      check_pass "GitHub environment '$env' exists"
    else
      check_warn "GitHub environment '$env' not found (optional, but recommended for protection rules)"
    fi
  done
else
  check_warn "Cannot check GitHub environments (GitHub CLI not available)"
fi

# Summary
print_header "Validation Summary"

TOTAL_CHECKS=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNING))

echo "Total Checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed:  $CHECKS_PASSED${NC}"
echo -e "${RED}Failed:  $CHECKS_FAILED${NC}"
echo -e "${YELLOW}Warnings: $CHECKS_WARNING${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ Validation passed! GitHub Actions should work correctly.${NC}"
  echo ""
  print_info "Next steps:"
  echo "  1. Test by creating a PR that modifies infrastructure files"
  echo "  2. Check that the infrastructure-whatif.yml workflow runs"
  echo "  3. Verify Azure login succeeds in the workflow logs"
  exit 0
else
  echo -e "${RED}❌ Validation failed. Please fix the issues above.${NC}"
  echo ""
  print_info "To fix issues, run:"
  echo "  ./setup-github-actions-azure.sh"
  echo ""
  print_info "For detailed help, see:"
  echo "  docs/GITHUB_ACTIONS_SETUP.md"
  exit 1
fi
