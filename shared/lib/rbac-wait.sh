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
