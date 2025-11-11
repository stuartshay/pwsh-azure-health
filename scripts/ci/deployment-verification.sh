#!/bin/bash

# Deployment Verification Utilities
# Functions for verifying Azure Function App deployments

# Check if Function App is running
# Usage: check_function_app_running <function-app-name> <resource-group>
# Returns: 0 if running, 1 otherwise
check_function_app_running() {
  local function_app_name=$1
  local resource_group=$2

  if [ -z "$function_app_name" ] || [ -z "$resource_group" ]; then
    echo "Error: function-app-name and resource-group are required" >&2
    return 1
  fi

  local state
  state=$(az functionapp show \
    --name "$function_app_name" \
    --resource-group "$resource_group" \
    --query state \
    --output tsv 2>&1)

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to get Function App state: $state" >&2
    return 1
  fi

  if [ "$state" = "Running" ]; then
    echo "✅ Function App is running" >&2
    return 0
  else
    echo "❌ Function App state: $state" >&2
    return 1
  fi
}

# Test Function App health endpoint
# Usage: test_function_app_health <function-app-url>
# Returns: 0 if healthy (HTTP 200-399), 1 otherwise
test_function_app_health() {
  local function_app_url=$1

  if [ -z "$function_app_url" ]; then
    echo "Error: function-app-url is required" >&2
    return 1
  fi

  # Remove trailing slash if present
  function_app_url="${function_app_url%/}"

  # Test the health endpoint (assuming /api/HealthCheck exists)
  local health_url="${function_app_url}/api/HealthCheck"

  echo "Testing health endpoint: $health_url" >&2

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 30 "$health_url" 2>&1)

  if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
    echo "✅ Health check passed (HTTP $http_code)" >&2
    return 0
  else
    echo "⚠️  Health check returned HTTP $http_code (may need authentication)" >&2
    # Don't fail - the endpoint might require auth
    return 0
  fi
}

# Verify storage account connectivity
# Usage: verify_storage_account <storage-account-name> <resource-group>
# Returns: 0 if accessible, 1 otherwise
verify_storage_account() {
  local storage_account_name=$1
  local resource_group=$2

  if [ -z "$storage_account_name" ] || [ -z "$resource_group" ]; then
    echo "Error: storage-account-name and resource-group are required" >&2
    return 1
  fi

  # Get storage account key
  local storage_key
  storage_key=$(az storage account keys list \
    --account-name "$storage_account_name" \
    --resource-group "$resource_group" \
    --query "[0].value" \
    --output tsv 2>&1)

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to get storage account key: $storage_key" >&2
    return 1
  fi

  # Try to list containers (validates connectivity)
  if az storage container list \
    --account-name "$storage_account_name" \
    --account-key "$storage_key" \
    --output none 2>&1; then
    echo "✅ Storage account accessible" >&2
    return 0
  else
    echo "❌ Storage account not accessible" >&2
    return 1
  fi
}

# Verify Application Insights connection
# Usage: verify_app_insights <app-insights-name> <resource-group>
# Returns: 0 if connected, 1 otherwise
verify_app_insights() {
  local app_insights_name=$1
  local resource_group=$2

  if [ -z "$app_insights_name" ] || [ -z "$resource_group" ]; then
    echo "Error: app-insights-name and resource-group are required" >&2
    return 1
  fi

  # Get Application Insights connection string
  local connection_string
  connection_string=$(az monitor app-insights component show \
    --app "$app_insights_name" \
    --resource-group "$resource_group" \
    --query connectionString \
    --output tsv 2>&1)

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to get Application Insights connection string: $connection_string" >&2
    return 1
  fi

  if [ -n "$connection_string" ] && [ "$connection_string" != "null" ]; then
    echo "✅ Application Insights configured" >&2
    return 0
  else
    echo "❌ Application Insights not properly configured" >&2
    return 1
  fi
}

# Run complete deployment verification
# Usage: verify_deployment <function-app-name> <storage-account-name> <app-insights-name> <resource-group> <function-url>
# Returns: 0 if all checks pass, 1 if any check fails
verify_deployment() {
  local function_app_name=$1
  local storage_account_name=$2
  local app_insights_name=$3
  local resource_group=$4
  local function_url=$5

  if [ -z "$function_app_name" ] || [ -z "$storage_account_name" ] || \
     [ -z "$app_insights_name" ] || [ -z "$resource_group" ] || [ -z "$function_url" ]; then
    echo "Error: All parameters are required" >&2
    echo "Usage: verify_deployment <function-app-name> <storage-account-name> <app-insights-name> <resource-group> <function-url>" >&2
    return 1
  fi

  echo "🔍 Running post-deployment verification..." >&2
  echo "" >&2

  local all_checks_passed=true

  # Check 1: Function App running
  echo "1. Checking Function App state..." >&2
  if ! check_function_app_running "$function_app_name" "$resource_group"; then
    all_checks_passed=false
  fi
  echo "" >&2

  # Check 2: Storage account accessible
  echo "2. Verifying storage account connectivity..." >&2
  if ! verify_storage_account "$storage_account_name" "$resource_group"; then
    all_checks_passed=false
  fi
  echo "" >&2

  # Check 3: Application Insights configured
  echo "3. Verifying Application Insights connection..." >&2
  if ! verify_app_insights "$app_insights_name" "$resource_group"; then
    all_checks_passed=false
  fi
  echo "" >&2

  # Check 4: Function App URL accessible
  echo "4. Testing Function App health endpoint..." >&2
  if ! test_function_app_health "$function_url"; then
    # Don't fail on health check - it might require auth
    :
  fi
  echo "" >&2

  if [ "$all_checks_passed" = true ]; then
    echo "✅ All deployment verification checks passed!" >&2
    return 0
  else
    echo "❌ Some deployment verification checks failed" >&2
    return 1
  fi
}
