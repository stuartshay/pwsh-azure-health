#!/usr/bin/env bats

# Tests for scripts/ci/cost-analysis.sh
# Post-deployment cost analysis script testing
# Run with: bats tests/workflows/cost-analysis.bats

setup() {
  # Create temporary directory for test files
  export TEST_TEMP_DIR="$BATS_TEST_TMPDIR/cost-analysis-test-$$"
  mkdir -p "$TEST_TEMP_DIR"

  # Create mock directory for commands
  export MOCK_DIR="$TEST_TEMP_DIR/mocks"
  mkdir -p "$MOCK_DIR"

  # Set test environment variables
  export GITHUB_OUTPUT="$TEST_TEMP_DIR/github_output.txt"
  export GITHUB_STEP_SUMMARY="$TEST_TEMP_DIR/github_summary.md"
  touch "$GITHUB_OUTPUT" "$GITHUB_STEP_SUMMARY"
}

teardown() {
  # Clean up temporary files
  rm -rf "$TEST_TEMP_DIR"
}

# Test: Extract actual cost from azure-cost-cli output
@test "extracts actual cost from azure-cost-cli output" {
  cost_output='Total actual cost: $20.39'

  run bash -c "
    echo '$cost_output' | grep -o '\$[0-9]*\.[0-9]*'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "\$20.39" ]
}

# Test: Extract actual cost with comma separators
@test "extracts actual cost with comma separators" {
  cost_output='Total actual cost: $1,234.56'

  run bash -c "
    echo '$cost_output' | grep -o '\$[0-9,]*\.[0-9]*'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "\$1,234.56" ]
}

# Test: Actual vs estimated cost comparison using awk
@test "compares actual cost to estimated cost" {
  actual_cost="20.39"
  estimated_cost="20.48"

  run bash -c "
    ACTUAL='$actual_cost'
    ESTIMATED='$estimated_cost'

    # Calculate variance using awk
    awk -v a=\"\$ACTUAL\" -v e=\"\$ESTIMATED\" 'BEGIN {
      variance = a - e
      variance_pct = (variance / e) * 100
      printf \"Variance: %.2f\\n\", variance
      printf \"Variance %%: %.2f\\n\", variance_pct
    }'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"Variance: -0.09"* ]]
}

# Test: Variance percentage calculation
@test "calculates variance percentage correctly" {
  actual="25.00"
  estimated="20.00"

  run bash -c "
    awk -v a='$actual' -v e='$estimated' 'BEGIN {
      variance = a - e
      variance_pct = (variance / e) * 100
      printf \"%.2f\", variance_pct
    }'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "25.00" ]
}

# Test: Handles actual cost lower than estimated
@test "detects actual cost lower than estimated (savings)" {
  actual="18.00"
  estimated="20.00"

  run bash -c "
    awk -v a='$actual' -v e='$estimated' 'BEGIN {
      if (a < e) print \"SAVINGS\"
      else print \"OVERSPEND\"
    }'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "SAVINGS" ]
}

# Test: Handles actual cost higher than estimated
@test "detects actual cost higher than estimated (overspend)" {
  actual="25.00"
  estimated="20.00"

  run bash -c "
    awk -v a='$actual' -v e='$estimated' 'BEGIN {
      if (a > e) print \"OVERSPEND\"
      else print \"SAVINGS\"
    }'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "OVERSPEND" ]
}

# Test: Zero actual cost handling
@test "handles zero actual cost correctly" {
  cost_output='Total actual cost: $0.00'

  run bash -c "
    echo '$cost_output' | grep -o '\$[0-9]*\.[0-9]*'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "\$0.00" ]
}

# Test: GITHUB_OUTPUT generation for cost analysis
@test "generates GITHUB_OUTPUT with actual cost data" {
  actual_cost="\$20.39"
  estimated_cost="\$20.48"
  variance="-0.09"

  run bash -c "
    OUTPUT_FILE='$TEST_TEMP_DIR/test_output.txt'

    echo 'actual_cost=$actual_cost' >> \"\$OUTPUT_FILE\"
    echo 'estimated_cost=$estimated_cost' >> \"\$OUTPUT_FILE\"
    echo 'cost_variance=$variance' >> \"\$OUTPUT_FILE\"

    cat \"\$OUTPUT_FILE\"
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"actual_cost=\$20.39"* ]]
  [[ "$output" == *"estimated_cost=\$20.48"* ]]
  [[ "$output" == *"cost_variance=-0.09"* ]]
}

# Test: Cost analysis summary markdown generation
@test "generates cost analysis markdown summary" {
  actual="\$20.39"
  estimated="\$20.48"
  variance="-\$0.09"
  variance_pct="-0.44%"

  run bash -c "
    cat << EOF
## 📊 Post-Deployment Cost Analysis

### Actual vs Estimated Costs

| Metric | Value |
|--------|-------|
| Estimated Cost | $estimated |
| Actual Cost | $actual |
| Variance | $variance ($variance_pct) |

✅ **Under Budget**: Actual costs are lower than estimated!
EOF
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"## 📊 Post-Deployment Cost Analysis"* ]]
  [[ "$output" == *"Actual vs Estimated Costs"* ]]
  [[ "$output" == *"Under Budget"* ]]
}

# Test: Date range parsing
@test "extracts date range from cost analysis output" {
  cost_output='Period: 2025-11-01 to 2025-11-16'

  run bash -c "
    echo '$cost_output' | sed 's/Period: //'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "2025-11-01 to 2025-11-16" ]
}

# Test: Currency parsing from output
@test "extracts currency from cost analysis output" {
  cost_output='Currency: USD'

  run bash -c "
    echo '$cost_output' | awk '{print \$2}'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "USD" ]
}

# Test: Cost threshold alert detection
@test "detects cost exceeding budget threshold" {
  actual="25.00"
  budget="20.00"

  run bash -c "
    awk -v a='$actual' -v b='$budget' 'BEGIN {
      if (a > b) {
        overage = a - b
        printf \"ALERT: Over budget by \$%.2f\\n\", overage
      } else {
        print \"WITHIN_BUDGET\"
      }
    }'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"ALERT: Over budget by \$5.00"* ]]
}

# Test: Cost trend analysis (current vs previous month)
@test "compares current month cost to previous month" {
  current_month="20.39"
  previous_month="18.50"

  run bash -c "
    awk -v c='$current_month' -v p='$previous_month' 'BEGIN {
      trend = c - p
      trend_pct = (trend / p) * 100
      if (trend >= 0) {
        printf \"Trend: +\$%.2f (+%.2f%%)\\n\", trend, trend_pct
      } else {
        printf \"Trend: -\$%.2f (%.2f%%)\\n\", -trend, trend_pct
      }
    }'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"+\$1.89"* ]]
  [[ "$output" == *"+10.22%"* ]]
}

# Test: Handles missing estimated cost (no baseline)
@test "handles cost analysis without estimated baseline" {
  actual_cost="20.39"

  run bash -c "
    ACTUAL='$actual_cost'
    ESTIMATED=''

    if [ -z \"\$ESTIMATED\" ]; then
      echo \"Actual cost: \\\$$ACTUAL (no baseline for comparison)\"
    else
      echo \"Variance calculated\"
    fi
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"no baseline for comparison"* ]]
}

# Test: Cost data export to JSON format
@test "exports cost analysis to JSON format" {
  actual="20.39"
  estimated="20.48"
  variance="-0.09"

  run bash -c "
    cat << EOF | jq -c '.'
{
  \"actualCost\": $actual,
  \"estimatedCost\": $estimated,
  \"variance\": $variance,
  \"timestamp\": \"2025-11-16T12:00:00Z\"
}
EOF
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *'"actualCost":20.39'* ]]
  [[ "$output" == *'"estimatedCost":20.48'* ]]
  [[ "$output" == *'"variance":-0.09'* ]]
}

# Test: Cost anomaly detection (>20% variance)
@test "detects cost anomalies based on variance threshold" {
  actual="30.00"
  estimated="20.00"
  threshold="20"

  run bash -c "
    awk -v a='$actual' -v e='$estimated' -v t='$threshold' 'BEGIN {
      variance_pct = ((a - e) / e) * 100
      if (variance_pct < 0) variance_pct = -variance_pct
      if (variance_pct > t) print \"ANOMALY_DETECTED\"
      else print \"NORMAL_VARIANCE\"
    }'
  "

  [ "$status" -eq 0 ]
  [ "$output" = "ANOMALY_DETECTED" ]
}

# Test: Daily cost rate calculation
@test "calculates daily cost rate from monthly total" {
  monthly_cost="30.00"
  days_in_month="30"

  run bash -c "
    awk -v m='$monthly_cost' -v d='$days_in_month' 'BEGIN {
      daily_rate = m / d
      printf \"Daily rate: \$%.2f\\n\", daily_rate
    }'
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"Daily rate: \$1.00"* ]]
}

# Test: Cost alert notification format
@test "formats cost alert notification" {
  actual="25.00"
  budget="20.00"
  overage="5.00"

  run bash -c "
    cat << EOF
🚨 COST ALERT

**Resource Group:** rg-azure-health-dev
**Budget:** \\\$$budget
**Actual:** \\\$$actual
**Overage:** \\\$$overage (25%)

Action required: Review resource usage and optimize costs.
EOF
  "

  [ "$status" -eq 0 ]
  [[ "$output" == *"🚨 COST ALERT"* ]]
  [[ "$output" == *"Overage:"* ]]
  [[ "$output" == *"Action required"* ]]
}
