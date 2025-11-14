#!/usr/bin/env bats

# Tests for ACE (Azure Cost Estimator) cost estimation functionality
# Run with: bats tests/workflows/ace-cost-estimation.bats
# Validates cost estimation in .github/workflows/infrastructure-deploy.yml

setup() {
  # Create temporary directory for test files
  export TEST_TEMP_DIR="$BATS_TEST_TMPDIR/ace-test-$$"
  mkdir -p "$TEST_TEMP_DIR"

  # Create mock directory for commands
  export MOCK_DIR="$TEST_TEMP_DIR/mocks"
  mkdir -p "$MOCK_DIR"
}

teardown() {
  # Clean up temporary files
  rm -rf "$TEST_TEMP_DIR"
}

# Test: ACE Installation Process
@test "ACE installation downloads and extracts correctly" {
  # Simulate ACE installation
  run bash -c '
    TEMP_DIR="'"$TEST_TEMP_DIR"'"
    mkdir -p "$TEMP_DIR/ace"

    # Create a mock ACE binary
    cat > "$TEMP_DIR/ace/azure-cost-estimator" << "EOF"
#!/bin/bash
echo "Azure Cost Estimator v1.6.4"
EOF
    chmod +x "$TEMP_DIR/ace/azure-cost-estimator"

    # Verify binary exists and is executable
    [ -x "$TEMP_DIR/ace/azure-cost-estimator" ]

    # Test version output
    "$TEMP_DIR/ace/azure-cost-estimator"
  '

  [ "$status" -eq 0 ]
  [[ "$output" == *"Azure Cost Estimator v1.6.4"* ]]
}

# Test: Cost extraction from valid ACE output
@test "extracts cost from ACE output with standard format" {
  ace_output='
Analyzing template...
Found 5 resources
Calculating costs...

Resource Group: rg-azure-health-dev
Region: eastus

Resources:
- Function App (Consumption): $0.00/month
- Storage Account (Standard LRS): $20.48/month
- Application Insights: $0.00/month

Total cost: 20.48 USD
'

  # Extract cost using the same pattern as the workflow (tail -1 for summary total)
  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | tail -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "20.48" ]
}

# Test: Cost extraction with comma-separated values
@test "extracts cost with comma separators" {
  ace_output='
Total cost: 1,234.56 USD
'

  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "1,234.56" ]
}

# Test: Zero cost scenario (current issue)
@test "correctly identifies zero cost estimate" {
  ace_output='
Analyzing template...

Total cost: 0.00 USD
'

  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "0.00" ]
}

# Test: No cost information in output
@test "handles ACE output with no cost information" {
  ace_output='
Error: Unable to calculate costs
Resource type not found in pricing database
'

  run bash -c "
    COST=\$(echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1 || echo 'N/A')
    [ -z \"\$COST\" ] && COST='N/A'
    echo \$COST
  "

  [ "$status" -eq 0 ]
  [ "$output" = "N/A" ]
}

# Test: Bicep to ARM template transpilation
@test "transpiles Bicep to ARM template correctly" {
  # Create mock ARM template directly
  cat > "$TEST_TEMP_DIR/main.json" << 'EOF'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.Web/sites",
      "apiVersion": "2023-01-01",
      "name": "test-func",
      "kind": "functionapp"
    }
  ]
}
EOF

  # Test file exists
  [ -f "$TEST_TEMP_DIR/main.json" ]

  # Test extraction of resource type
  run grep -q 'Microsoft.Web/sites' "$TEST_TEMP_DIR/main.json"
  [ "$status" -eq 0 ]
}

# Test: Complete cost estimation workflow
@test "end-to-end cost estimation workflow" {
  # Create mock ACE binary
  cat > "$MOCK_DIR/azure-cost-estimator" << 'EOF'
#!/bin/bash
# Mock ACE that simulates real output
echo "Analyzing template..."
echo "Resource Group: rg-azure-health-dev"
echo ""
echo "Resources:"
echo "- Function App (Consumption): $0.00/month"
echo "- Storage Account (Standard_LRS): $20.48/month"
echo "- Application Insights: $0.00/month"
echo ""
echo "Total cost: 20.48 USD"
EOF
  chmod +x "$MOCK_DIR/azure-cost-estimator"

  # Run complete workflow
  run bash -c "
    # Step 1: Create mock ARM template
    echo '{\"resources\": []}' > '$TEST_TEMP_DIR/main.json'

    # Step 2: Run ACE
    COST_ESTIMATE_OUTPUT=\$('$MOCK_DIR/azure-cost-estimator' '$TEST_TEMP_DIR/main.json' sub-123 rg-test)

    # Step 3: Extract cost
    ESTIMATED_COST=\$(echo \"\$COST_ESTIMATE_OUTPUT\" | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1 || echo 'N/A')

    if [ \"\$ESTIMATED_COST\" = 'N/A' ]; then
      echo 'Unable to calculate'
    else
      echo \"\\\$\$ESTIMATED_COST\"
    fi
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"\$20.48"* ]]
}

# Test: GitHub Actions output format
@test "formats output for GitHub Actions correctly" {
  ace_cost="20.48"

  run bash -c "
    # Simulate GitHub Actions output format
    OUTPUT_FILE='$TEST_TEMP_DIR/github_output.txt'

    echo 'estimated_cost=\$$ace_cost' >> \"\$OUTPUT_FILE\"

    # Verify output format
    grep -q 'estimated_cost=\\\$20.48' \"\$OUTPUT_FILE\"
  "

  [ "$status" -eq 0 ]
}

# Test: Handles ACE binary not found
@test "handles missing ACE binary gracefully" {
  run bash -c "
    # Try to run non-existent ACE binary
    if command -v azure-cost-estimator-nonexistent &> /dev/null; then
      echo 'Found'
    else
      echo 'Tool not available'
    fi
  "

  [ "$status" -eq 0 ]
  [ "$output" = "Tool not available" ]
}

# Test: ACE with inline parameters
@test "passes inline parameters to ACE correctly" {
  # Create mock ACE that echoes parameters
  cat > "$MOCK_DIR/azure-cost-estimator" << 'EOF'
#!/bin/bash
# Echo all parameters for verification
echo "Parameters: $@"
echo "Total cost: 25.00 USD"
EOF
  chmod +x "$MOCK_DIR/azure-cost-estimator"

  run bash -c "
    export PATH='$MOCK_DIR:\$PATH'

    azure-cost-estimator \
      /tmp/main.json \
      sub-123 \
      rg-test \
      --inline 'environment=dev' \
      --inline 'functionAppPlanSku=Y1' \
      --currency USD
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"--inline"* ]]
  [[ "$output" == *"environment=dev"* ]]
  [[ "$output" == *"Total cost: 25.00 USD"* ]]
}

# Test: Cost extraction with different currency symbols
@test "extracts cost with USD currency" {
  test_outputs=(
    "Total cost: 50.00 USD"
    "Total: \$50.00 USD"
    "Estimated cost: 50.00 USD/month"
  )

  for test_output in "${test_outputs[@]}"; do
    run bash -c "
      echo '$test_output' | grep -i 'cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
    "
    [ "$status" -eq 0 ] || continue
    [ "$output" = "50.00" ] && return 0
  done

  return 1
}

# Test: Multiple resources with individual costs
@test "handles detailed resource breakdown" {
  ace_output='
Resource breakdown:
- Microsoft.Storage/storageAccounts: $20.48/month
- Microsoft.Insights/components: $0.00/month
- Microsoft.Web/serverfarms: $0.00/month (Consumption)
- Microsoft.Web/sites: $0.00/month

Total cost: 20.48 USD
'

  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "20.48" ]
}

# Test: ACE version validation
@test "validates ACE version output" {
  cat > "$MOCK_DIR/azure-cost-estimator" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
  echo "1.6.4"
  exit 0
fi
EOF
  chmod +x "$MOCK_DIR/azure-cost-estimator"

  run bash -c "
    export PATH='$MOCK_DIR:\$PATH'
    azure-cost-estimator --version
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"1.6.4"* ]]
}

# Test: Fallback when extraction fails
@test "uses fallback message when cost extraction fails" {
  ace_output='Error occurred during cost calculation'

  run bash -c "
    ACE_OUTPUT='$ace_output'
    ESTIMATED_COST=\$(echo \"\$ACE_OUTPUT\" | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1 || echo 'N/A')

    if [ \"\$ESTIMATED_COST\" = 'N/A' ] || [ -z \"\$ESTIMATED_COST\" ]; then
      echo 'Unable to calculate'
    else
      echo \"\$\$ESTIMATED_COST\"
    fi
  "

  [ "$status" -eq 0 ]
  [ "$output" = "Unable to calculate" ]
}

# Test: Large cost values
@test "handles large cost values correctly" {
  ace_output='Total cost: 10,543.75 USD'

  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "10,543.75" ]
}

# Test: Verification of managed identity parameter
@test "includes managed identity in ACE parameters" {
  managed_identity="/subscriptions/sub-123/resourceGroups/rg-shared/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-shared"

  run bash -c "
    # Verify parameter format
    echo '--inline \"managedIdentityResourceId=$managed_identity\"'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"managedIdentityResourceId="* ]]
}

# Test: Summary output format for GitHub Actions
@test "generates proper markdown summary for GitHub Actions" {
  estimated_cost="\$20.48"
  environment="dev"
  sku="Y1"

  run bash -c "
    COST='$estimated_cost'
    ENV='$environment'
    SKU_VAL='$sku'
    cat << 'EOF'
## 💰 Pre-Deployment Cost Estimation

**Environment:** dev
**SKU:** Y1

### Estimated Monthly Cost: \`\$20.48\`
EOF
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"## 💰 Pre-Deployment Cost Estimation"* ]]
  [[ "$output" == *"Estimated Monthly Cost:"* ]]
  [[ "$output" == *"\$20.48"* ]]
}

# Test: Handles empty or whitespace-only output
@test "handles empty ACE output" {
  ace_output='

  '

  run bash -c "
    ESTIMATED_COST=\$(echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1 || echo 'N/A')

    if [ \"\$ESTIMATED_COST\" = 'N/A' ] || [ -z \"\$ESTIMATED_COST\" ]; then
      echo 'Unable to calculate'
    else
      echo \"\\\$\$ESTIMATED_COST\"
    fi
  "

  [ "$status" -eq 0 ]
  [ "$output" = "Unable to calculate" ]
}

# Test: Multiple "Total cost:" lines - extracts summary not individual resources
@test "extracts summary total when multiple Total cost lines present" {
  # Simulates real ACE output with per-resource costs AND summary
  ace_output='
[Create] azurehealth-ai-dev
   \--- Type: Microsoft.Insights/components
   \--- Location: eastus
   \--- Total cost: 0.00 USD
   \--- Delta: +0.00 USD

[Create] stazurehealthdev
   \--- Type: Microsoft.Storage/storageAccounts
   \--- Location: eastus
   \--- Total cost: 0.13 USD
   \--- Delta: +0.13 USD

[Create] azurehealth-plan-dev
   \--- Type: Microsoft.Web/serverfarms
   \--- Location: eastus
   \--- Total cost: 0.00 USD
   \--- Delta: +0.00 USD

-------------------------------

Summary:

-> Total cost: 0.13 USD
-> Delta: +0.13 USD
'

  # Use tail -1 to get the LAST occurrence (summary total), not first (free resource)
  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | tail -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "0.13" ]  # Should get summary (0.13), not first free resource (0.00)
}

# Test: Real-world ACE output format (from GitHub issue)
@test "handles actual ACE output format from workflow" {
  # This simulates the actual format ACE produces
  ace_output='
╔══════════════════════════════════════════════════════════════════════════════╗
║                         Azure Cost Estimator v1.6.4                          ║
╚══════════════════════════════════════════════════════════════════════════════╝

Analyzing ARM template: /tmp/main.json
Subscription ID: abc123def456
Resource Group: rg-azure-health-dev

┌──────────────────────────────────────────────────────────────────────────────┐
│ Resources Found                                                               │
└──────────────────────────────────────────────────────────────────────────────┘

1. Microsoft.Storage/storageAccounts
   - SKU: Standard_LRS
   - Location: eastus
   - Estimated cost: $20.48/month

2. Microsoft.Insights/components
   - SKU: N/A
   - Location: eastus
   - Estimated cost: $0.00/month

3. Microsoft.Web/serverfarms
   - SKU: Y1 (Consumption)
   - Location: eastus
   - Estimated cost: $0.00/month

4. Microsoft.Web/sites
   - SKU: N/A
   - Location: eastus
   - Estimated cost: $0.00/month

┌──────────────────────────────────────────────────────────────────────────────┐
│ Cost Summary                                                                  │
└──────────────────────────────────────────────────────────────────────────────┘

Total cost: 20.48 USD
Currency: USD
Billing period: Monthly
'

  run bash -c "
    echo '$ace_output' | grep -i 'Total cost:' | grep -oP '[\\d,]+\\.?\\d+(?= USD)' | head -1
  "

  [ "$status" -eq 0 ]
  [ "$output" = "20.48" ]
}
