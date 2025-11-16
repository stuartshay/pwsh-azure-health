#!/usr/bin/env bash

# Reusable helper to pull post-deployment actual costs using azure-cost-cli.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cost-analysis.sh --resource-group <name> --subscription-id <id> [options]

Options:
  --resource-group <name>   Resource group to query (required)
  --subscription-id <id>    Azure subscription ID (required)
  --timeframe <period>      Timeframe for cost query (default: MonthToDate)
  --summary-path <path>     File to append markdown summary (default: $GITHUB_STEP_SUMMARY if set)
EOF
}

append_output() {
  local key=$1 value=$2
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s=%s\n' "$key" "$value" >>"$GITHUB_OUTPUT"
  fi
}

append_heredoc_output() {
  local key=$1 content=$2
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
      printf '%s<<EOF\n' "$key"
      printf '%s\n' "$content"
      echo "EOF"
    } >>"$GITHUB_OUTPUT"
  fi
}

# Defaults
TIMEFRAME="MonthToDate"
SUMMARY_PATH="${GITHUB_STEP_SUMMARY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --subscription-id) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --timeframe) TIMEFRAME="$2"; shift 2 ;;
    --summary-path) SUMMARY_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "${RESOURCE_GROUP:-}" ] || [ -z "${SUBSCRIPTION_ID:-}" ]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

SUMMARY_PATH="${SUMMARY_PATH:-}"

echo "💰 Analyzing actual deployment costs with azure-cost-cli..."
echo ""
echo "⏳ Querying Azure Cost Management API for resource group costs..."
echo "Note: Newly deployed resources may take 8-24 hours to appear in cost data"
echo ""

# Verify azure-cost availability
if ! command -v azure-cost >/dev/null 2>&1; then
  echo "❌ azure-cost not found in PATH"
  echo "PATH: $PATH"
  ls -la "$HOME/.dotnet/tools/" 2>/dev/null || echo "dotnet tools directory not found"
  ACTUAL_COST="Tool not available"
  COST_STATUS="❌ azure-cost-cli not installed"
  ACTUAL_COST_OUTPUT=""
else
  echo "✅ Found azure-cost: $(command -v azure-cost)"

  set +e
  ACTUAL_COST_OUTPUT=$(azure-cost \
    --subscription "$SUBSCRIPTION_ID" \
    --resource-group "$RESOURCE_GROUP" \
    --output json \
    --timeframe "$TIMEFRAME" 2>&1)
  CMD_EXIT=$?
  set -e

  echo "Raw output:"
  echo "$ACTUAL_COST_OUTPUT"
  echo ""

  ACTUAL_COST="N/A"
  if [ $CMD_EXIT -eq 0 ] && echo "$ACTUAL_COST_OUTPUT" | jq -e . >/dev/null 2>&1; then
    ACTUAL_COST=$(echo "$ACTUAL_COST_OUTPUT" | jq -r '.totalCost // .Total // "N/A"' 2>/dev/null || echo "N/A")
  fi

  if [ "$ACTUAL_COST" = "N/A" ] || [ "$ACTUAL_COST" = "null" ]; then
    echo "⚠️  Actual cost data not yet available (resources were just deployed)"
    ACTUAL_COST="Not yet available"
    COST_STATUS="⏳ Pending (check in 24 hours)"
  else
    echo "💵 Actual cost ($TIMEFRAME): \$$ACTUAL_COST"
    COST_STATUS="✅ Available"
  fi
fi

append_output "actual_cost" "$ACTUAL_COST"
append_output "cost_status" "$COST_STATUS"
append_heredoc_output "actual_cost_details" "$ACTUAL_COST_OUTPUT"

if [ -n "$SUMMARY_PATH" ]; then
  {
    echo "## 💵 Post-Deployment Cost Analysis"
    echo ""
    echo "**Resource Group:** \`$RESOURCE_GROUP\`"
    echo "**Time Period:** $TIMEFRAME"
    echo "**Status:** $COST_STATUS"
    echo ""
    echo "### Actual Cost: \`\$$ACTUAL_COST\`"
    echo ""
    if [ "$ACTUAL_COST" != "Not yet available" ] && [ "$ACTUAL_COST" != "N/A" ]; then
      echo "<details>"
      echo "<summary>View detailed cost breakdown</summary>"
      echo ""
      echo '```'
      echo "$ACTUAL_COST_OUTPUT"
      echo '```'
      echo ""
      echo "</details>"
    else
      echo "> **Note:** Cost data for newly deployed resources typically becomes available within 8-24 hours."
      echo "> You can check actual costs later using:"
      echo "> \`\`\`bash"
      echo "> az costmanagement query \\"
      echo ">   --type ActualCost \\"
      echo ">   --dataset-filter \"{\\\"and\\\":[{\\\"dimensions\\\":{\\\"name\\\":\\\"ResourceGroup\\\",\\\"operator\\\":\\\"In\\\",\\\"values\\\":[\\\"$RESOURCE_GROUP\\\"]}}]}\" \\"
      echo ">   --timeframe $TIMEFRAME"
      echo "> \`\`\`"
    fi
    echo ""
    echo "---"
  } >>"$SUMMARY_PATH"
fi

echo "Cost analysis completed."
