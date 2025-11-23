#!/usr/bin/env bats

# Tests for deployment verification utilities
# Run with: bats tests/workflows/deployment-verification.bats

# Note: Downloads shared deployment-verification.sh from shared-azure-health repository
setup() {
  # Download and load the shared deployment verification utilities
  curl -sSL https://raw.githubusercontent.com/stuartshay/shared-azure-health/master/scripts/deployment-verification.sh -o /tmp/deployment-verification-test.sh
  # shellcheck disable=SC1091
  source /tmp/deployment-verification-test.sh

  export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCK_DIR"
  export PATH="$MOCK_DIR:$PATH"
}

teardown() {
  rm -rf "$MOCK_DIR"
}

# Test: check_function_app_running with running app
@test "check_function_app_running succeeds when app is running" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"functionapp show"* ]]; then
  echo "Running"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run check_function_app_running "test-func" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ Function App is running"* ]]
}

# Test: check_function_app_running with stopped app
@test "check_function_app_running fails when app is stopped" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"functionapp show"* ]]; then
  echo "Stopped"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run check_function_app_running "test-func" "test-rg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"❌ Function App state: Stopped"* ]]
}

# Test: check_function_app_running without parameters
@test "check_function_app_running fails without required parameters" {
  run check_function_app_running "test-func" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: function-app-name and resource-group are required"* ]]
}

# Test: test_function_app_health with healthy endpoint
@test "test_function_app_health succeeds with 200 response" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "200"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_function_app_health "https://test-func.azurewebsites.net"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ Health check passed (HTTP 200)"* ]]
}

# Test: test_function_app_health with auth required (401)
@test "test_function_app_health handles 401 gracefully" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "401"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_function_app_health "https://test-func.azurewebsites.net"
  [ "$status" -eq 0 ]  # Don't fail on auth required
  [[ "$output" == *"⚠️  Health check returned HTTP 401"* ]]
}

# Test: test_function_app_health without URL
@test "test_function_app_health fails without URL" {
  run test_function_app_health ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: function-app-url is required"* ]]
}

# Test: verify_storage_account with accessible storage
@test "verify_storage_account succeeds when storage is accessible" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"storage account keys list"* ]]; then
  echo "test-key-12345"
  exit 0
elif [[ "$*" == *"storage container list"* ]]; then
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_storage_account "teststorage" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ Storage account accessible"* ]]
}

# Test: verify_storage_account when key retrieval fails
@test "verify_storage_account fails when cannot get key" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"storage account keys list"* ]]; then
  echo "ERROR: Access denied" >&2
  exit 1
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_storage_account "teststorage" "test-rg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to get storage account key"* ]]
}

# Test: verify_storage_account without parameters
@test "verify_storage_account fails without required parameters" {
  run verify_storage_account "" "test-rg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: storage-account-name and resource-group are required"* ]]
}

# Test: verify_app_insights with configured insights
@test "verify_app_insights succeeds when insights is configured" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"app-insights component show"* ]]; then
  echo "InstrumentationKey=12345678-1234-1234-1234-123456789abc;IngestionEndpoint=https://test.in.applicationinsights.azure.com/"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_app_insights "test-insights" "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ Application Insights configured"* ]]
}

# Test: verify_app_insights when not configured
@test "verify_app_insights fails when connection string is null" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"app-insights component show"* ]]; then
  echo "null"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_app_insights "test-insights" "test-rg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"❌ Application Insights not properly configured"* ]]
}

# Test: verify_app_insights without parameters
@test "verify_app_insights fails without required parameters" {
  run verify_app_insights "test-insights" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: app-insights-name and resource-group are required"* ]]
}

# Test: verify_deployment complete workflow - all pass
@test "verify_deployment succeeds when all checks pass" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"functionapp show"* ]]; then
  echo "Running"
elif [[ "$*" == *"storage account keys list"* ]]; then
  echo "test-key-12345"
elif [[ "$*" == *"storage container list"* ]]; then
  exit 0
elif [[ "$*" == *"app-insights component show"* ]]; then
  echo "InstrumentationKey=test"
fi
exit 0
EOF
  chmod +x "$MOCK_DIR/az"

  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "200"
EOF
  chmod +x "$MOCK_DIR/curl"

  run verify_deployment "test-func" "teststorage" "test-insights" "test-rg" "https://test-func.azurewebsites.net"
  [ "$status" -eq 0 ]
  [[ "$output" == *"✅ All deployment verification checks passed!"* ]]
}

# Test: verify_deployment with one failure
@test "verify_deployment fails when function app is not running" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"functionapp show"* ]]; then
  echo "Stopped"
elif [[ "$*" == *"storage account keys list"* ]]; then
  echo "test-key-12345"
elif [[ "$*" == *"storage container list"* ]]; then
  exit 0
elif [[ "$*" == *"app-insights component show"* ]]; then
  echo "InstrumentationKey=test"
fi
exit 0
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_deployment "test-func" "teststorage" "test-insights" "test-rg" "https://test-func.azurewebsites.net"
  [ "$status" -eq 1 ]
  [[ "$output" == *"❌ Some deployment verification checks failed"* ]]
}

# Test: verify_deployment without parameters
@test "verify_deployment fails without required parameters" {
  run verify_deployment "test-func" "" "test-insights" "test-rg" "https://test-func.azurewebsites.net"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: All parameters are required"* ]]
}
