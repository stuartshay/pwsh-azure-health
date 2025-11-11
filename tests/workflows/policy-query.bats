#!/usr/bin/env bats

# Tests for policy query utilities
# Run with: bats tests/workflows/policy-query.bats

# shellcheck disable=SC1091
source "${BATS_TEST_DIRNAME}/../../scripts/ci/policy-query.sh"

setup() {
  # Create temporary directory for mock scripts
  export MOCK_DIR="$BATS_TEST_TMPDIR/mocks"
  mkdir -p "$MOCK_DIR"
  export PATH="$MOCK_DIR:$PATH"
}

teardown() {
  # Clean up mocks
  rm -rf "$MOCK_DIR"
}

# Test: get_policy_assignments with valid resource group
@test "get_policy_assignments returns assignments for resource group" {
  # Mock az command
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_assignments "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"assignment1"* ]]
  [[ "$output" == *"Test Assignment"* ]]
}

# Test: get_policy_assignments with no assignments
@test "get_policy_assignments returns empty array when no assignments" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
echo "[]"
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_assignments "test-rg"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# Test: get_policy_assignments without resource group parameter
@test "get_policy_assignments fails without resource group" {
  run get_policy_assignments
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: get_policy_exemptions with valid resource group
@test "get_policy_exemptions returns exemptions for resource group" {
  # Mock az commands
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"account show"* ]]; then
  echo "12345678-1234-1234-1234-123456789abc"
elif [[ "$*" == *"policy exemption list"* ]]; then
  echo '[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver","expiresOn":"2025-12-31"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_exemptions "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exemption1"* ]]
  [[ "$output" == *"Test Exemption"* ]]
  [[ "$output" == *"Waiver"* ]]
}

# Test: get_policy_exemptions with no exemptions
@test "get_policy_exemptions returns empty array when no exemptions" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"account show"* ]]; then
  echo "12345678-1234-1234-1234-123456789abc"
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_exemptions "test-rg"
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

# Test: get_policy_exemptions without resource group parameter
@test "get_policy_exemptions fails without resource group" {
  run get_policy_exemptions
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: get_policy_exemptions fails when subscription ID unavailable
@test "get_policy_exemptions fails when cannot get subscription ID" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"account show"* ]]; then
  exit 1
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run get_policy_exemptions "test-rg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Failed to get subscription ID"* ]]
}

# Test: format_policy_assignments with valid assignments
@test "format_policy_assignments formats assignments correctly" {
  local json='[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","complianceState":"Compliant"}]'

  run format_policy_assignments "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Assignments (1):"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Test Assignment**"* ]]
  [[ "$output" == *"_Compliant_"* ]]
}

# Test: format_policy_assignments with multiple assignments
@test "format_policy_assignments handles multiple assignments" {
  local json='[
    {"name":"assignment1","displayName":"Assignment One","enforcementMode":"Default","complianceState":"NonCompliant"},
    {"name":"assignment2","displayName":"Assignment Two","enforcementMode":"DoNotEnforce","complianceState":"Compliant"}
  ]'

  run format_policy_assignments "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Assignments (2):"* ]]
  [[ "$output" == *"❌"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Assignment One**"* ]]
  [[ "$output" == *"**Assignment Two**"* ]]
}

# Test: format_policy_assignments with empty array
@test "format_policy_assignments handles empty array" {
  run format_policy_assignments "[]"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy assignments found"* ]]
}

# Test: format_policy_assignments with null/empty input
@test "format_policy_assignments handles null input" {
  run format_policy_assignments ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy assignments found"* ]]
}

# Test: format_policy_assignments with invalid JSON
@test "format_policy_assignments handles invalid JSON gracefully" {
  run format_policy_assignments "not-valid-json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to parse policy assignments"* ]]
}

# Test: format_policy_exemptions with valid exemptions
@test "format_policy_exemptions formats exemptions correctly" {
  local json='[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver","expiresOn":"2025-12-31"}]'

  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Exemptions (1):"* ]]
  [[ "$output" == *"**Test Exemption** (Waiver)"* ]]
  [[ "$output" == *"Expires: 2025-12-31"* ]]
}

# Test: format_policy_exemptions without expiration date
@test "format_policy_exemptions handles exemptions without expiration" {
  local json='[{"name":"exemption1","displayName":"Permanent Exemption","exemptionCategory":"Mitigated"}]'

  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"**Permanent Exemption** (Mitigated)"* ]]
  [[ "$output" != *"Expires:"* ]]
}

# Test: format_policy_exemptions with empty array
@test "format_policy_exemptions handles empty array" {
  run format_policy_exemptions "[]"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No policy exemptions found"* ]]
}

# Test: format_policy_exemptions with multiple exemptions
@test "format_policy_exemptions handles multiple exemptions" {
  local json='[
    {"name":"ex1","displayName":"Exemption One","exemptionCategory":"Waiver","expiresOn":"2025-12-31"},
    {"name":"ex2","displayName":"Exemption Two","exemptionCategory":"Mitigated"}
  ]'

  run format_policy_exemptions "$json"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Policy Exemptions (2):"* ]]
  [[ "$output" == *"**Exemption One** (Waiver)"* ]]
  [[ "$output" == *"**Exemption Two** (Mitigated)"* ]]
}

# Test: generate_policy_report complete workflow
@test "generate_policy_report creates complete formatted report" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"account show"* ]]; then
  echo "12345678-1234-1234-1234-123456789abc"
elif [[ "$*" == *"policy assignment list"* ]]; then
  echo '[{"name":"assignment1","displayName":"Test Assignment","enforcementMode":"Default","policyDefinitionId":"/subscriptions/test/providers/Microsoft.Authorization/policyDefinitions/test-policy"}]'
elif [[ "$*" == *"policy state list"* ]]; then
  echo '[{"policyAssignment":"assignment1","compliance":"Compliant"}]'
elif [[ "$*" == *"policy exemption list"* ]]; then
  echo '[{"name":"exemption1","displayName":"Test Exemption","exemptionCategory":"Waiver"}]'
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run generate_policy_report "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Azure Policy Status"* ]]
  [[ "$output" == *"Policy Assignments (1):"* ]]
  [[ "$output" == *"✅"* ]]
  [[ "$output" == *"**Test Assignment**"* ]]
  [[ "$output" == *"Policy Exemptions (1):"* ]]
  [[ "$output" == *"**Test Exemption** (Waiver)"* ]]
}

# Test: generate_policy_report without resource group
@test "generate_policy_report fails without resource group" {
  run generate_policy_report
  [ "$status" -eq 1 ]
  [[ "$output" == *"Error: Resource group name is required"* ]]
}

# Test: generate_policy_report with no policies
@test "generate_policy_report handles resource group with no policies" {
  cat > "$MOCK_DIR/az" << 'EOF'
#!/bin/bash
if [[ "$*" == *"account show"* ]]; then
  echo "12345678-1234-1234-1234-123456789abc"
else
  echo "[]"
fi
EOF
  chmod +x "$MOCK_DIR/az"

  run generate_policy_report "test-rg"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Azure Policy Status"* ]]
  [[ "$output" == *"No policy assignments found"* ]]
  [[ "$output" == *"No policy exemptions found"* ]]
}
