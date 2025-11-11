#!/usr/bin/env bats

# Tests for deployment output parsing
# Run with: bats tests/workflows/deployment-output.bats

setup() {
  # Mock az command for testing
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
}

# Test: Parsing deployment output with Bicep warnings
@test "handles deployment output with bicep warnings" {
  # Create a mock that simulates az deployment output with warnings
  mkdir -p "$BATS_TEST_TMPDIR/mocks"
  cat > "$BATS_TEST_TMPDIR/mocks/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"deployment group create"* ]] && [[ "$*" == *"--output json"* ]]; then
  # Simulate Bicep warnings before JSON output (this corrupts JSON parsing)
  cat << 'AZEOF'
WARNING: /path/to/main.bicep(61,25) : Warning BCP081: Resource type "Microsoft.Storage/storageAccounts@2025-06-01" does not have types available.
WARNING: /path/to/main.bicep(88,22) : Warning BCP081: Resource type "Microsoft.Storage/storageAccounts/blobServices@2025-06-01" does not have types available.
{
  "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Resources/deployments/test",
  "properties": {
    "outputs": {
      "functionAppName": {"value": "test-func"},
      "storageAccountName": {"value": "teststorage"}
    }
  }
}
AZEOF
elif [[ "$*" == *"deployment group show"* ]]; then
  # Clean JSON output without warnings
  cat << 'AZEOF'
{
  "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Resources/deployments/test",
  "properties": {
    "outputs": {
      "functionAppName": {"value": "test-func"},
      "storageAccountName": {"value": "teststorage"}
    }
  }
}
AZEOF
else
  echo '{"result": "ok"}'
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/mocks/az"

  # Test that direct capture with --output json fails validation
  run bash -c '
    export PATH="'"$BATS_TEST_TMPDIR/mocks"':$PATH"
    output=$(az deployment group create --output json)
    echo "$output" | jq empty 2>/dev/null
  '
  [ "$status" -ne 0 ]  # Should fail because warnings corrupt JSON

  # Test that querying separately works
  run bash -c '
    export PATH="'"$BATS_TEST_TMPDIR/mocks"':$PATH"
    output=$(az deployment group show)
    echo "$output" | jq empty 2>/dev/null
  '
  [ "$status" -eq 0 ]  # Should succeed with clean JSON
}

# Test: Extracting outputs from clean JSON
@test "extracts deployment outputs correctly" {
  # Create clean deployment JSON
  deployment_json='{
    "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Resources/deployments/test",
    "properties": {
      "outputs": {
        "functionAppName": {"value": "my-function-app"},
        "storageAccountName": {"value": "mystorage123"},
        "appInsightsName": {"value": "my-insights"}
      }
    }
  }'

  # Extract values
  run bash -c "echo '$deployment_json' | jq -r '.properties.outputs.functionAppName.value'"
  [ "$status" -eq 0 ]
  [ "$output" = "my-function-app" ]

  run bash -c "echo '$deployment_json' | jq -r '.properties.outputs.storageAccountName.value'"
  [ "$status" -eq 0 ]
  [ "$output" = "mystorage123" ]

  run bash -c "echo '$deployment_json' | jq -r '.properties.outputs.appInsightsName.value'"
  [ "$status" -eq 0 ]
  [ "$output" = "my-insights" ]
}

# Test: Validates JSON before parsing
@test "validates json before attempting to parse" {
  # Invalid JSON
  run bash -c 'echo "WARNING: Some warning message" | jq empty 2>/dev/null'
  [ "$status" -ne 0 ]

  # Valid JSON
  run bash -c 'echo "{\"test\": \"value\"}" | jq empty 2>/dev/null'
  [ "$status" -eq 0 ]
}

# Test: Handles missing outputs gracefully
@test "handles deployment with missing outputs" {
  deployment_json='{
    "id": "/subscriptions/test/resourceGroups/test-rg/providers/Microsoft.Resources/deployments/test",
    "properties": {
      "outputs": {}
    }
  }'

  # Extract non-existent value (should return "null")
  run bash -c "echo '$deployment_json' | jq -r '.properties.outputs.nonExistent.value'"
  [ "$status" -eq 0 ]
  [ "$output" = "null" ]
}

# Test: Recommended deployment pattern
@test "recommended pattern: deploy with --output none then query" {
  mkdir -p "$BATS_TEST_TMPDIR/mocks"
  cat > "$BATS_TEST_TMPDIR/mocks/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"deployment group create"* ]] && [[ "$*" == *"--output none"* ]]; then
  # No output when using --output none
  exit 0
elif [[ "$*" == *"deployment group show"* ]]; then
  # Clean JSON output
  echo '{"properties": {"outputs": {"functionAppName": {"value": "test-func"}}}}'
else
  echo '{"result": "ok"}'
fi
EOF
  chmod +x "$BATS_TEST_TMPDIR/mocks/az"

  # Simulate recommended pattern
  run bash -c '
    export PATH="'"$BATS_TEST_TMPDIR/mocks"':$PATH"
    # Deploy without capturing output
    az deployment group create --output none
    # Query separately for clean JSON
    output=$(az deployment group show)
    echo "$output" | jq -r ".properties.outputs.functionAppName.value"
  '
  [ "$status" -eq 0 ]
  [ "$output" = "test-func" ]
}
