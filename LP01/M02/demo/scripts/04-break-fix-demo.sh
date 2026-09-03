#!/usr/bin/env bash
# Slide 19: live break/fix walkthrough. Previously this was just printed
# instructions in 03-verify-troubleshoot.sh - this script actually runs
# them: break WEBSITES_PORT, prove the app fails, fix it, prove it recovers.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

if ! az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output none 2>/dev/null; then
  echo "Web app '$WEBAPP_NAME' not found. Run ./01-deploy-app-service.sh first." >&2
  exit 1
fi

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
HEALTH_URL="https://${HOSTNAME}/health"

check_health() {
  local label="$1" expect_ok="$2"
  for attempt in $(seq 1 12); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
    if { [ "$expect_ok" = "true" ] && [ "$STATUS" = "200" ]; } || \
       { [ "$expect_ok" = "false" ] && [ "$STATUS" != "200" ]; }; then
      echo "$label: HTTP $STATUS (as expected) after ${attempt} attempt(s)."
      return 0
    fi
    echo "  attempt ${attempt}: HTTP $STATUS - waiting 10s..."
    sleep 10
  done
  echo "$label: did not reach expected state after 2 minutes (last status: $STATUS)." >&2
  return 1
}

echo "== Baseline: confirm the app is currently healthy =="
check_health "Baseline" true

echo
echo "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=9999 --output none
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Confirm it's actually broken =="
check_health "Broken state" false || true

echo
echo "== Fix it: restore the correct port =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=8000 --output none
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Confirm it recovered =="
check_health "Recovered" true
