#!/bin/bash

# Azure Key Vault Utilities
# Functions for managing and validating Key Vault secrets

# Set a secret in Key Vault
# Usage: set_keyvault_secret <vault-name> <secret-name> <secret-value>
# Returns: 0 on success, 1 on failure
set_keyvault_secret() {
  local vault_name=$1
  local secret_name=$2
  local secret_value=$3

  if [ -z "$vault_name" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
    echo "Error: vault-name, secret-name, and secret-value are required" >&2
    return 1
  fi

  az keyvault secret set \
    --vault-name "$vault_name" \
    --name "$secret_name" \
    --value "$secret_value" \
    --output none 2>&1

  return $?
}

# Get a secret from Key Vault
# Usage: get_keyvault_secret <vault-name> <secret-name>
# Returns: Secret value on success, error message on stderr if failed
get_keyvault_secret() {
  local vault_name=$1
  local secret_name=$2

  if [ -z "$vault_name" ] || [ -z "$secret_name" ]; then
    echo "Error: vault-name and secret-name are required" >&2
    return 1
  fi

  local secret_value
  secret_value=$(az keyvault secret show \
    --vault-name "$vault_name" \
    --name "$secret_name" \
    --query value \
    --output tsv 2>&1)

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "$secret_value" >&2
    return $exit_code
  fi

  echo "$secret_value"
  return 0
}

# Verify a secret value matches expected value
# Usage: verify_keyvault_secret <vault-name> <secret-name> <expected-value>
# Returns: 0 if matches, 1 if doesn't match or error
verify_keyvault_secret() {
  local vault_name=$1
  local secret_name=$2
  local expected_value=$3

  if [ -z "$vault_name" ] || [ -z "$secret_name" ] || [ -z "$expected_value" ]; then
    echo "Error: vault-name, secret-name, and expected-value are required" >&2
    return 1
  fi

  local actual_value
  actual_value=$(get_keyvault_secret "$vault_name" "$secret_name" 2>&1)

  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "Error: Failed to retrieve secret: $actual_value" >&2
    return 1
  fi

  if [ "$actual_value" = "$expected_value" ]; then
    return 0
  else
    echo "Error: Secret value mismatch" >&2
    echo "Expected: $expected_value" >&2
    echo "Actual: $actual_value" >&2
    return 1
  fi
}

# Test URL accessibility
# Usage: test_url_accessible <url>
# Returns: 0 if accessible (HTTP 200-399), 1 otherwise
test_url_accessible() {
  local url=$1

  if [ -z "$url" ]; then
    echo "Error: URL is required" >&2
    return 1
  fi

  # Use curl to test URL (follow redirects, timeout 10s, only check headers)
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url" 2>&1)

  if [[ "$http_code" =~ ^[23][0-9][0-9]$ ]]; then
    return 0
  else
    echo "Error: URL not accessible (HTTP $http_code): $url" >&2
    return 1
  fi
}

# Update Key Vault secret and verify
# Usage: update_and_verify_keyvault_secret <vault-name> <secret-name> <secret-value>
# Returns: 0 on success, 1 on failure
update_and_verify_keyvault_secret() {
  local vault_name=$1
  local secret_name=$2
  local secret_value=$3

  if [ -z "$vault_name" ] || [ -z "$secret_name" ] || [ -z "$secret_value" ]; then
    echo "Error: vault-name, secret-name, and secret-value are required" >&2
    return 1
  fi

  echo "Updating Key Vault secret: $secret_name" >&2
  echo "Key Vault: $vault_name" >&2

  # Set the secret
  if ! set_keyvault_secret "$vault_name" "$secret_name" "$secret_value"; then
    echo "Error: Failed to set secret in Key Vault" >&2
    return 1
  fi

  echo "✅ Secret updated successfully" >&2

  # Verify the secret was set correctly
  echo "Verifying secret value..." >&2
  if ! verify_keyvault_secret "$vault_name" "$secret_name" "$secret_value"; then
    echo "❌ Secret verification failed" >&2
    return 1
  fi

  echo "✅ Secret verified successfully" >&2
  return 0
}
