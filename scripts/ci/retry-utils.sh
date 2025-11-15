#!/bin/bash

# Retry function with exponential backoff for Azure operations
# Usage: retry_azure_operation <max_attempts> <description> <command...>
retry_azure_operation() {
  local max_attempts=$1
  shift
  local description=$1
  shift
  local command=("$@")

  local attempt=1
  local delay=${RETRY_BASE_DELAY:-2}
  local max_delay=32

  echo "🔄 Starting: $description" >&2

  while [ $attempt -le $max_attempts ]; do
    echo "  Attempt $attempt/$max_attempts..." >&2

    # Execute command and capture output
    local output
    local exit_code

    set +e  # Temporarily disable exit on error
    output=$("${command[@]}" 2>&1)
    exit_code=$?
    # Note: Do not re-enable set -e here to allow caller to capture exit code

    # Success
    if [ $exit_code -eq 0 ]; then
      echo "$output"
      echo "✅ Success: $description" >&2
      return 0
    fi

    # Check for permanent failures (don't retry)
    if echo "$output" | grep -qE \
      "(AuthorizationFailed|InvalidAuthenticationToken|Forbidden|InvalidResourceGroupName|RequestDisallowedByPolicy|PolicyViolation)"; then
      echo "❌ Permanent failure detected: $description" >&2
      echo "$output" >&2

      # If it's a policy violation, provide helpful context
      if echo "$output" | grep -qE "(RequestDisallowedByPolicy|PolicyViolation)"; then
        echo "" >&2
        echo "⛔ Policy Denial Detected" >&2
        echo "This deployment was blocked by an Azure Policy." >&2
        echo "Review the policy assignments and ensure your deployment complies with requirements." >&2
        echo "" >&2
      fi

      return $exit_code
    fi

    # Last attempt failed
    if [ $attempt -eq $max_attempts ]; then
      echo "❌ Failed after $max_attempts attempts: $description" >&2
      echo "$output" >&2
      return $exit_code
    fi

    # Check if it's a known transient error
    local error_type="Unknown error"
    if echo "$output" | grep -qE "TooManyRequests|429"; then
      error_type="Rate limit (429)"
    elif echo "$output" | grep -qE "ServiceUnavailable|503"; then
      error_type="Service unavailable (503)"
    elif echo "$output" | grep -qE "GatewayTimeout|504"; then
      error_type="Gateway timeout (504)"
    elif echo "$output" | grep -qE "InternalServerError|500"; then
      error_type="Internal server error (500)"
    elif echo "$output" | grep -qE "Conflict|409"; then
      error_type="Conflict (409)"
    fi

    echo "⚠️  $error_type - Retrying in ${delay}s..." >&2
    echo "    Error preview: $(echo "$output" | head -n 1)" >&2

    sleep $delay

    # Exponential backoff
    delay=$((delay * 2))
    if [ $delay -gt $max_delay ]; then
      delay=$max_delay
    fi

    attempt=$((attempt + 1))
  done
}
