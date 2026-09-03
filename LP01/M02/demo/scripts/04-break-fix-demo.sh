#!/usr/bin/env bash
# Slide 19: live break/fix walkthrough. Previously this was just printed
# instructions in 03-verify-troubleshoot.sh - this script actually runs
# them: break WEBSITES_PORT, prove the app fails, fix it, prove it recovers.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/app-health.sh

if ! az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output none 2>/dev/null; then
  echo "Web app '$WEBAPP_NAME' not found. Run ./01-deploy-app-service.sh first." >&2
  exit 1
fi

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
HEALTH_URL="https://${HOSTNAME}/health"

echo "== Baseline: confirm the app is currently healthy =="
wait_for_app_health "$HEALTH_URL" true

echo
echo "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=9999 --output none
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Confirm it's actually broken =="
# App Service serves its own HTTP 200 placeholder page while a container
# is failing to start, so this can take a couple of minutes AND needs the
# body-aware check above - a plain status-code check would report "fine"
# the entire time because the placeholder page is also a 200.
wait_for_app_health "$HEALTH_URL" false 18 10 || true

echo
echo "== Fix it: restore the correct port =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=8000 --output none
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Confirm it recovered =="
wait_for_app_health "$HEALTH_URL" true
