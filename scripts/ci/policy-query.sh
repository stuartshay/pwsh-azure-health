#!/bin/bash

# Azure Policy Query Utilities
# Functions for querying policy assignments and exemptions

# Query policy assignments for a resource group
# Usage: get_policy_assignments <resource-group-name>
# Returns: JSON array of policy assignments
get_policy_assignments() {
  local resource_group=$1

  if [ -z "$resource_group" ]; then
    echo "Error: Resource group name is required" >&2
    return 1
  fi

  az policy assignment list \
    --resource-group "$resource_group" \
    --query "[].{name:name, displayName:displayName, enforcementMode:enforcementMode}" \
    --output json 2>/dev/null || echo "[]"
}

# Query policy exemptions for a resource group
# Usage: get_policy_exemptions <resource-group-name>
# Returns: JSON array of policy exemptions
get_policy_exemptions() {
  local resource_group=$1

  if [ -z "$resource_group" ]; then
    echo "Error: Resource group name is required" >&2
    return 1
  fi

  # Get subscription ID and build resource group scope
  local subscription_id
  subscription_id=$(az account show --query id -o tsv 2>/dev/null)

  if [ -z "$subscription_id" ]; then
    echo "Error: Failed to get subscription ID" >&2
    return 1
  fi

  local rg_scope="/subscriptions/$subscription_id/resourceGroups/$resource_group"

  # Query exemptions that apply to this resource group
  az policy exemption list \
    --query "[?contains(policyAssignmentId, '$rg_scope') || \
      contains(resourceSelector, '$rg_scope')].{name:name, displayName:displayName, \
      exemptionCategory:exemptionCategory, expiresOn:expiresOn}" \
    --output json 2>/dev/null || echo "[]"
}

# Format policy assignments for display
# Usage: format_policy_assignments <json-array>
# Returns: Markdown-formatted text
format_policy_assignments() {
  local assignments=$1

  if [ -z "$assignments" ]; then
    echo "- ℹ️ No policy assignments found for this resource group"
    return 0
  fi

  local count
  count=$(echo "$assignments" | jq 'length' 2>/dev/null)

  if [ -z "$count" ] || [ "$count" = "null" ]; then
    echo "- ℹ️ Failed to parse policy assignments"
    return 0
  fi

  if [ "$count" -eq 0 ]; then
    echo "- ℹ️ No policy assignments found for this resource group"
    return 0
  fi

  echo "**Policy Assignments ($count):**"
  echo ""
  echo "$assignments" | jq -r \
    '.[] | "- **\(.displayName // .name)** (\(.enforcementMode // "Default"))"'
}

# Format policy exemptions for display
# Usage: format_policy_exemptions <json-array>
# Returns: Markdown-formatted text
format_policy_exemptions() {
  local exemptions=$1

  if [ -z "$exemptions" ]; then
    echo "- ℹ️ No policy exemptions found for this resource group"
    return 0
  fi

  local count
  count=$(echo "$exemptions" | jq 'length' 2>/dev/null)

  if [ -z "$count" ] || [ "$count" = "null" ]; then
    echo "- ℹ️ Failed to parse policy exemptions"
    return 0
  fi

  if [ "$count" -eq 0 ]; then
    echo "- ℹ️ No policy exemptions found for this resource group"
    return 0
  fi

  echo "**Policy Exemptions ($count):**"
  echo ""
  echo "$exemptions" | jq -r '.[] | "- **\(.displayName // .name)** (\(.exemptionCategory))" + (if .expiresOn then " - Expires: \(.expiresOn)" else "" end)'
}

# Generate complete policy status report
# Usage: generate_policy_report <resource-group-name>
# Returns: Markdown-formatted policy status report
generate_policy_report() {
  local resource_group=$1

  if [ -z "$resource_group" ]; then
    echo "Error: Resource group name is required" >&2
    return 1
  fi

  echo "#### Azure Policy Status"
  echo ""

  # Get and format policy assignments
  local assignments
  assignments=$(get_policy_assignments "$resource_group")
  format_policy_assignments "$assignments"

  echo ""

  # Get and format policy exemptions
  local exemptions
  exemptions=$(get_policy_exemptions "$resource_group")
  format_policy_exemptions "$exemptions"
}
