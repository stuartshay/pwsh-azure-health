#!/usr/bin/env bats

# Tests for Key Vault utilities
# Run with: bats tests/workflows/keyvault.bats

# Note: Downloads shared keyvault-utils.sh from shared-azure-health repository
setup() {
  # Download and load the shared keyvault utilities
  curl -sSL https://raw.githubusercontent.com/stuartshay/shared-azure-health/master/scripts/keyvault-utils.sh -o /tmp/keyvault-utils-test.sh
  # shellcheck disable=SC1091
  source /tmp/keyvault-utils-test.sh

  # Create temporary directory for mock scripts
  export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCK_DIR"
  export PATH="$MOCK_DIR:$PATH"
}

teardown() {
  # Clean up mocks
  rm -rf "$MOCK_DIR"
}

# Test: set_keyvault_secret with valid parameters
@test "set_keyvault_secret sets secret successfully" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret set"* ]]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_DIR/az"

  run set_keyvault_secret "test-vault" "test-secret" "test-value"
  [ "$status" -eq 0 ]
}

# Test: set_keyvault_secret without vault name
@test "set_keyvault_secret fails without vault name" {
  run set_keyvault_secret "" "test-secret" "test-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name, secret-name, and secret-value are required"* ]]
}

# Test: set_keyvault_secret without secret name
@test "set_keyvault_secret fails without secret name" {
  run set_keyvault_secret "test-vault" "" "test-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name, secret-name, and secret-value are required"* ]]
}

# Test: set_keyvault_secret without secret value
@test "set_keyvault_secret fails without secret value" {
  run set_keyvault_secret "test-vault" "test-secret" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name, secret-name, and secret-value are required"* ]]
}

# Test: get_keyvault_secret with valid parameters
@test "get_keyvault_secret retrieves secret successfully" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret show"* ]]; then
  echo "my-secret-value"
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_DIR/az"

  run get_keyvault_secret "test-vault" "test-secret"
  [ "$status" -eq 0 ]
  [ "$output" = "my-secret-value" ]
}

# Test: get_keyvault_secret without vault name
@test "get_keyvault_secret fails without vault name" {
  run get_keyvault_secret "" "test-secret"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name and secret-name are required"* ]]
}

# Test: get_keyvault_secret without secret name
@test "get_keyvault_secret fails without secret name" {
  run get_keyvault_secret "test-vault" ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name and secret-name are required"* ]]
}

# Test: get_keyvault_secret when secret doesn't exist
@test "get_keyvault_secret handles non-existent secret" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret show"* ]]; then
  echo "ERROR: Secret not found" >&2
  exit 1
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_keyvault_secret "test-vault" "non-existent"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: Secret not found"* ]]
}

# Test: verify_keyvault_secret with matching value
@test "verify_keyvault_secret succeeds when values match" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret show"* ]]; then
  echo "expected-value"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_keyvault_secret "test-vault" "test-secret" "expected-value"
  [ "$status" -eq 0 ]
}

# Test: verify_keyvault_secret with mismatched value
@test "verify_keyvault_secret fails when values don't match" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret show"* ]]; then
  echo "actual-value"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run verify_keyvault_secret "test-vault" "test-secret" "expected-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Secret value mismatch"* ]]
  [[ "$output" == *"Expected: expected-value"* ]]
  [[ "$output" == *"Actual: actual-value"* ]]
}

# Test: verify_keyvault_secret without parameters
@test "verify_keyvault_secret fails without required parameters" {
  run verify_keyvault_secret "test-vault" "" "expected-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name, secret-name, and expected-value are required"* ]]
}

# Test: test_url_accessible with accessible URL
@test "test_url_accessible succeeds for 200 response" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "200"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_url_accessible "https://example.com"
  [ "$status" -eq 0 ]
}

# Test: test_url_accessible with redirect (3xx)
@test "test_url_accessible succeeds for 301 response" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "301"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_url_accessible "https://example.com"
  [ "$status" -eq 0 ]
}

# Test: test_url_accessible with 404
@test "test_url_accessible fails for 404 response" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "404"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_url_accessible "https://example.com/notfound"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: URL not accessible (HTTP 404)"* ]]
}

# Test: test_url_accessible with 500
@test "test_url_accessible fails for 500 response" {
  cat > "$MOCK_DIR/curl" << 'EOF'
#!/bin/bash
echo "500"
EOF
  chmod +x "$MOCK_DIR/curl"

  run test_url_accessible "https://example.com/error"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: URL not accessible (HTTP 500)"* ]]
}

# Test: test_url_accessible without URL
@test "test_url_accessible fails without URL" {
  run test_url_accessible ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: URL is required"* ]]
}

# Test: update_and_verify_keyvault_secret complete workflow
@test "update_and_verify_keyvault_secret updates and verifies successfully" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret set"* ]]; then
  exit 0
elif [[ "$*" == *"keyvault secret show"* ]]; then
  echo "test-value"
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_DIR/az"

  run update_and_verify_keyvault_secret "test-vault" "test-secret" "test-value"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Updating Key Vault secret: test-secret"* ]]
  [[ "$output" == *"✅ Secret updated successfully"* ]]
  [[ "$output" == *"Verifying secret value..."* ]]
  [[ "$output" == *"✅ Secret verified successfully"* ]]
}

# Test: update_and_verify_keyvault_secret fails on set error
@test "update_and_verify_keyvault_secret fails when set fails" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret set"* ]]; then
  exit 1
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run update_and_verify_keyvault_secret "test-vault" "test-secret" "test-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to set secret in Key Vault"* ]]
}

# Test: update_and_verify_keyvault_secret fails on verification error
@test "update_and_verify_keyvault_secret fails when verification fails" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"keyvault secret set"* ]]; then
  exit 0
elif [[ "$*" == *"keyvault secret show"* ]]; then
  echo "wrong-value"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run update_and_verify_keyvault_secret "test-vault" "test-secret" "test-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"✅ Secret updated successfully"* ]]
  [[ "$output" == *"❌ Secret verification failed"* ]]
}

# Test: update_and_verify_keyvault_secret without parameters
@test "update_and_verify_keyvault_secret fails without required parameters" {
  run update_and_verify_keyvault_secret "test-vault" "" "test-value"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: vault-name, secret-name, and secret-value are required"* ]]
}
