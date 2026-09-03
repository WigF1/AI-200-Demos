#!/usr/bin/env bash
# Shared helper: wait for an RBAC role assignment to propagate before the
# resource that needs it (e.g. a webapp pulling from ACR, or reading a Key
# Vault secret) tries to use it. Role assignments are visible in the ARM
# control plane almost immediately, but the data-plane services that
# actually enforce them (ACR, Key Vault, Storage, etc.) can lag behind by
# up to a couple of minutes. Polling the assignment first avoids a fixed
# multi-minute sleep on every run; the short buffer afterwards covers the
# data-plane lag that polling alone can't see.
#
# Usage: source this file, then:
#   wait_for_role_assignment "$PRINCIPAL_ID" "$SCOPE" "$ROLE"
#
# Or, to create the assignment idempotently (skip if it already exists,
# so re-running a script doesn't hit "RoleAssignmentExists") and then
# wait for it to propagate in one call:
#   ensure_role_assignment "$PRINCIPAL_ID" "$SCOPE" "$ROLE"

wait_for_role_assignment() {
  local principal_id="$1" scope="$2" role="$3"
  local max_attempts=12 attempt=0

  echo "Waiting for role assignment to appear: '$role' on $scope for principal $principal_id ..."
  until [ -n "$(az role assignment list --assignee "$principal_id" --scope "$scope" --role "$role" --query "[0].id" --output tsv 2>/dev/null)" ]; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "  Still not visible after $((max_attempts * 10))s - continuing anyway (assignment may just be slow to list)." >&2
      break
    fi
    sleep 10
  done

  echo "Role assignment visible. Waiting an extra 30s for data-plane propagation (ACR/Key Vault/etc. token caches)..."
  sleep 30
}

ensure_role_assignment() {
  local principal_id="$1" scope="$2" role="$3"

  local existing
  existing=$(az role assignment list --assignee "$principal_id" --scope "$scope" --role "$role" --query "[0].id" --output tsv 2>/dev/null)
  if [ -n "$existing" ]; then
    echo "Role assignment already exists: '$role' on $scope for principal $principal_id."
    return 0
  fi

  echo "Creating role assignment: '$role' on $scope for principal $principal_id ..."
  az role assignment create --assignee "$principal_id" --scope "$scope" --role "$role" --output none
  wait_for_role_assignment "$principal_id" "$scope" "$role"
}

# Usage: get_current_principal_id
# Returns the object ID of whoever is currently signed in to az CLI,
# whether that's an interactive user or a service principal (e.g. in
# CI/CD). az ad signed-in-user show only works for interactive users; it
# fails outright for service principals, so we fall back to resolving the
# service principal's object ID from its app/client ID instead.
get_current_principal_id() {
  local principal_id
  principal_id=$(az ad signed-in-user show --query id --output tsv 2>/dev/null) || true
  if [ -z "$principal_id" ]; then
    local app_id
    app_id=$(az account show --query user.name --output tsv)
    principal_id=$(az ad sp show --id "$app_id" --query id --output tsv)
  fi
  echo "$principal_id"
}
