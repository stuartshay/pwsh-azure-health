#!/bin/bash

# Reusable helper to perform pre-deployment cost estimation.
# Provides a primary PowerShell-based estimate and a secondary ACE estimate.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: cost-estimate.sh --environment <env> --sku <sku> --location <region> --subscription-id <id> [options]

Options:
  --environment <env>          Deployment environment (dev|prod|staging, etc.)
  --sku <sku>                  Function App plan SKU (Y1|EP1|EP2|EP3)
  --location <region>          Azure region for estimation (e.g., eastus)
  --subscription-id <id>       Azure subscription ID (required for ACE)
  --resource-group <name>      Resource group name (for summaries)
  --managed-identity-id <id>   Managed identity resource ID (passed to ACE)
  --bicep-file <path>          Path to Bicep template (default: infrastructure/main.bicep)
  --summary-path <path>        File to append markdown summary (default: $GITHUB_STEP_SUMMARY if set)
EOF
}

log() { echo "[$(date +'%H:%M:%S')] $*"; }

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
RESOURCE_GROUP=""
MANAGED_IDENTITY_RESOURCE_ID=""
BICEP_FILE="infrastructure/main.bicep"
SUMMARY_PATH="${GITHUB_STEP_SUMMARY:-}"

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --sku) SKU="$2"; shift 2 ;;
    --location) LOCATION="$2"; shift 2 ;;
    --subscription-id) SUBSCRIPTION_ID="$2"; shift 2 ;;
    --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
    --managed-identity-id) MANAGED_IDENTITY_RESOURCE_ID="$2"; shift 2 ;;
    --bicep-file) BICEP_FILE="$2"; shift 2 ;;
    --summary-path) SUMMARY_PATH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

if [ -z "${ENVIRONMENT:-}" ] || [ -z "${SKU:-}" ] || [ -z "${LOCATION:-}" ] || [ -z "${SUBSCRIPTION_ID:-}" ]; then
  echo "Missing required arguments." >&2
  usage
  exit 1
fi

log "Starting cost estimation for env=${ENVIRONMENT}, sku=${SKU}, location=${LOCATION}"

# -------------------------------------------------------
# Primary estimator (PowerShell)
# -------------------------------------------------------
log "Running PowerShell cost estimator..."
set +e
PWSH_COST_OUTPUT=$(pwsh ./scripts/infrastructure/estimate-costs.ps1 \
  -Environment "$ENVIRONMENT" \
  -Sku "$SKU" \
  -Region "$LOCATION" \
  -OutputFormat both \
  -Validate 2>&1)
PWSH_EXIT_CODE=$?
set -e

log "PowerShell estimator exit code: $PWSH_EXIT_CODE"
echo "$PWSH_COST_OUTPUT"

# Extract the last JSON object from the output (for machine-readable values)
# Use Python to reliably extract JSON from mixed text output
PWSH_JSON=$(python3 -c '
import json, sys, re
text = sys.stdin.read()
# Find the last complete JSON object in the output
matches = list(re.finditer(r"\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\}", text, re.DOTALL))
if matches:
    try:
        obj = json.loads(matches[-1].group(0))
        print(json.dumps(obj))
    except:
        print("{}")
else:
    print("{}")
' <<< "$PWSH_COST_OUTPUT" || echo '{}')

PWSH_TOTAL_COST="N/A"
PWSH_FUNCTION_COST="N/A"
PWSH_STORAGE_COST="N/A"
PWSH_AI_COST="N/A"

if [ -n "$PWSH_JSON" ] && [ "$PWSH_JSON" != "{}" ]; then
  PWSH_TOTAL_COST=$(echo "$PWSH_JSON" | jq -r '.Costs.Total.MonthlyCost' 2>/dev/null || echo "N/A")
  PWSH_FUNCTION_COST=$(echo "$PWSH_JSON" | jq -r '.Costs.FunctionAppPlan.MonthlyCost' 2>/dev/null || echo "N/A")
  PWSH_STORAGE_COST=$(echo "$PWSH_JSON" | jq -r '.Costs.Storage.MonthlyCost' 2>/dev/null || echo "N/A")
  PWSH_AI_COST=$(echo "$PWSH_JSON" | jq -r '.Costs.ApplicationInsights.MonthlyCost' 2>/dev/null || echo "N/A")
fi

if [ "$PWSH_EXIT_CODE" -ne 0 ]; then
  log "PowerShell validation failed (exit code $PWSH_EXIT_CODE); continuing with recorded values."
else
  log "PowerShell cost estimation completed successfully."
fi

# -------------------------------------------------------
# Secondary estimator (ACE)
# -------------------------------------------------------
log "Running ACE cost estimator..."
az bicep build \
  --file "$BICEP_FILE" \
  --outfile /tmp/main.json

set +e
ACE_COST_OUTPUT=$(/tmp/ace/azure-cost-estimator \
  /tmp/main.json \
  "$SUBSCRIPTION_ID" \
  "${RESOURCE_GROUP:-rg-placeholder}" \
  --inline "environment=$ENVIRONMENT" \
  --inline "functionAppPlanSku=$SKU" \
  --inline "managedIdentityResourceId=$MANAGED_IDENTITY_RESOURCE_ID" \
  --currency USD 2>&1)
set -e

echo "$ACE_COST_OUTPUT"

ACE_TOTAL_COST=$(echo "$ACE_COST_OUTPUT" | grep -i "Total cost:" | grep -oP '[\d,]+\.?\d+(?= USD)' | tail -1 || true)
ACE_TOTAL_COST=${ACE_TOTAL_COST:-N/A}

if [ "$ACE_TOTAL_COST" = "N/A" ]; then
  log "Could not extract ACE cost estimate."
else
  log "ACE estimated monthly cost: \$$ACE_TOTAL_COST USD"
fi

# -------------------------------------------------------
# Sanity checks (only for EP1 primary)
# -------------------------------------------------------
if [ "$SKU" = "EP1" ] && [ "$PWSH_TOTAL_COST" != "N/A" ]; then
  if (( $(echo "$PWSH_TOTAL_COST < 100" | bc -l 2>/dev/null || echo 0) )); then
    echo "❌ ERROR: EP1 cost estimate (\$$PWSH_TOTAL_COST) is suspiciously low; expected ~\$147/month." >&2
    exit 1
  fi
fi

# -------------------------------------------------------
# Outputs for GHA
# -------------------------------------------------------
append_output "pwsh_total_cost" "\$$PWSH_TOTAL_COST"
append_output "ace_total_cost" "\$$ACE_TOTAL_COST"
append_output "function_cost" "\$$PWSH_FUNCTION_COST"
append_output "storage_cost" "\$$PWSH_STORAGE_COST"
append_output "ai_cost" "\$$PWSH_AI_COST"
append_heredoc_output "pwsh_cost_details" "$PWSH_COST_OUTPUT"
append_heredoc_output "ace_cost_details" "$ACE_COST_OUTPUT"

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
if [ -n "$SUMMARY_PATH" ]; then
  {
    echo "## 💰 Pre-Deployment Cost Estimation"
    echo ""
    echo "**Environment:** $ENVIRONMENT"
    [ -n "$RESOURCE_GROUP" ] && echo "**Resource Group:** $RESOURCE_GROUP"
    echo "**SKU:** $SKU"
    echo "**Region:** $LOCATION"
    echo ""
    echo "### Primary Estimate (PowerShell): \`\$$PWSH_TOTAL_COST USD/month\`"
    echo ""
    echo "| Resource | Monthly Cost |"
    echo "|----------|--------------|"
    echo "| Function App Plan ($SKU) | \`\$$PWSH_FUNCTION_COST\` |"
    echo "| Storage Account (Standard LRS) | \`\$$PWSH_STORAGE_COST\` |"
    echo "| Application Insights | \`\$$PWSH_AI_COST\` |"
    echo "| **Total** | **\`\$$PWSH_TOTAL_COST\`** |"
    echo ""
    echo "### Secondary Estimate (ACE): \`\$$ACE_TOTAL_COST USD/month\`"
    echo ""
    # Variance warning if both available
    if [ "$PWSH_TOTAL_COST" != "N/A" ] && [ "$ACE_TOTAL_COST" != "N/A" ] && [ "$ACE_TOTAL_COST" != "Unable to calculate" ]; then
      PWSH_NUM=$(echo "$PWSH_TOTAL_COST" | tr -d '$,')
      ACE_NUM=$(echo "$ACE_TOTAL_COST" | tr -d '$,')
      DIFF=$(echo "scale=2; ($PWSH_NUM - $ACE_NUM) / $PWSH_NUM * 100" | bc -l 2>/dev/null || echo "0")
      ABS_DIFF=$(echo "$DIFF" | tr -d '-')
      if (( $(echo "$ABS_DIFF > 10" | bc -l 2>/dev/null || echo 0) )); then
        echo "> **⚠️ Note:** Significant difference detected between estimators (${ABS_DIFF}% variance)."
        echo "> The PowerShell estimator uses official Azure pricing and is more accurate."
        echo ""
      fi
    fi
    echo "<details>"
    echo "<summary>View PowerShell detailed cost breakdown</summary>"
    echo ""
    echo '```'
    echo "$PWSH_COST_OUTPUT"
    echo '```'
    echo ""
    echo "</details>"
    echo ""
    echo "<details>"
    echo "<summary>View ACE cost breakdown (reference)</summary>"
    echo ""
    echo '```'
    echo "$ACE_COST_OUTPUT"
    echo '```'
    echo ""
    echo "</details>"
    echo ""
    echo "---"
  } >>"$SUMMARY_PATH"
fi

log "Cost estimation completed."
