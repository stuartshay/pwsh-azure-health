#!/bin/bash

# Azure Policy Query Utilities
# Functions for querying policy assignments and exemptions

# Query policy assignments for a resource group with compliance state
# Usage: get_policy_assignments_with_compliance <resource-group-name>
# Returns: JSON array of policy assignments with compliance information
get_policy_assignments_with_compliance() {
  local resource_group=$1

  if [ -z "$resource_group" ]; then
    echo "Error: Resource group name is required" >&2
    return 1
  fi

  # Get policy assignments
  local assignments
  assignments=$(az policy assignment list \
    --resource-group "$resource_group" \
    --query "[].{name:name, displayName:displayName, enforcementMode:enforcementMode, policyDefinitionId:policyDefinitionId}" \
    --output json 2>/dev/null || echo "[]")

  # Get all compliance states for the resource group
  local all_states
  all_states=$(az policy state list \
    --resource-group "$resource_group" \
    --query "[].{policyAssignment:policyAssignmentName, compliance:complianceState}" \
    --output json 2>/dev/null || echo "[]")

  # For each policy assignment, find the worst compliance state (NonCompliant > Compliant)
  echo "$assignments" | jq --argjson states "$all_states" '
    map(. as $assignment |
      ($states | map(select(.policyAssignment == $assignment.name)) | map(.compliance)) as $complianceStates |
      (if ($complianceStates | any(. == "NonCompliant")) then "NonCompliant"
       elif ($complianceStates | any(. == "Compliant")) then "Compliant"
       else "Unknown"
       end) as $overallState |
      $assignment + {complianceState: $overallState}
    )'
}

# Get policy definition description
# Usage: get_policy_description <policy-definition-id>
# Returns: Policy description text
get_policy_description() {
  local policy_def_id=$1

  if [ -z "$policy_def_id" ]; then
    return 1
  fi

  # Extract policy definition name from ID
  local policy_name
  policy_name=$(basename "$policy_def_id")

  az policy definition show \
    --name "$policy_name" \
    --query "description" \
    --output tsv 2>/dev/null || echo ""
}

# Query policy assignments for a resource group (legacy function, kept for compatibility)
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

  # Sort: NonCompliant first, then Compliant, then others
  # Format with checkbox/X and include description
  echo "$assignments" | jq -r '
    sort_by(
      if .complianceState == "NonCompliant" then 0
      elif .complianceState == "Compliant" then 1
      else 2
      end
    ) |
    .[] |
    (if .complianceState == "Compliant" then "  - ✅ "
     elif .complianceState == "NonCompliant" then "  - ❌ "
     else "  - ⚪ "
     end) +
    "**\(.displayName // .name)**" +
    (if .enforcementMode != "Default" then " (\(.enforcementMode))" else "" end) +
    (if .complianceState and .complianceState != "Unknown" then " - _\(.complianceState)_" else "" end)
  '

  # Add descriptions for policies with definition IDs
  echo ""
  echo "$assignments" | jq -r '
    sort_by(
      if .complianceState == "NonCompliant" then 0
      elif .complianceState == "Compliant" then 1
      else 2
      end
    ) |
    .[] |
    select(.policyDefinitionId) |
    .policyDefinitionId
  ' | while read -r policy_def_id; do
    if [ -n "$policy_def_id" ]; then
      local description
      description=$(get_policy_description "$policy_def_id")
      if [ -n "$description" ]; then
        local policy_name
        policy_name=$(basename "$policy_def_id")
        echo "    <details>"
        echo "    <summary><em>$policy_name</em></summary>"
        echo ""
        echo "    $description"
        echo "    </details>"
      fi
    fi
  done
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

  # Get policy assignments with compliance states
  local assignments
  assignments=$(get_policy_assignments_with_compliance "$resource_group")
  format_policy_assignments "$assignments"

  echo ""

  # Get and format policy exemptions
  local exemptions
  exemptions=$(get_policy_exemptions "$resource_group")
  format_policy_exemptions "$exemptions"
}
