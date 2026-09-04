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

echo "NOTE: this uses 'az webapp stop' + 'az webapp start' rather than 'az webapp restart'."
echo "Testing showed 'restart' doesn't reliably tear down the container that's already"
echo "serving traffic - a new (broken) container can fail behind the scenes while Azure"
echo "keeps the old one alive and answering requests, making the app LOOK unaffected."
echo "A full stop guarantees nothing is left running before the bad config is applied."
echo "Also avoid running other scripts against this app (e.g. 03-verify-troubleshoot.sh)"
echo "while this is running - any config change triggers its own restart, which can still"
echo "race this one."
echo

HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
HEALTH_URL="https://${HOSTNAME}/health"

echo "== Baseline: confirm the app is currently healthy =="
wait_for_app_health "$HEALTH_URL" true

echo
echo "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=9999 --output none
az webapp stop --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
az webapp start --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

# Self-check: confirm the setting actually stuck before trusting the health
# poll below. If something else (another script, a concurrent restart)
# raced this and the live value isn't 9999, the "still healthy" result
# that follows would otherwise look like a mystery instead of explaining
# itself.
LIVE_PORT=$(az webapp config appsettings list --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --query "[?name=='WEBSITES_PORT'].value | [0]" --output tsv)
if [ "$LIVE_PORT" != "9999" ]; then
  echo "WARNING: WEBSITES_PORT currently reads '$LIVE_PORT', not 9999 - something else changed" >&2
  echo "it (likely a concurrent restart from another script). The 'confirm broken' check" >&2
  echo "below is not trustworthy this run - stop, make sure no other script is touching" >&2
  echo "this app, and re-run." >&2
fi

echo "== Confirm it's actually broken =="
# App Service serves its own HTTP 200 placeholder page while a container
# is failing to start, so this can take a couple of minutes AND needs the
# body-aware check above - a plain status-code check would report "fine"
# the entire time because the placeholder page is also a 200.
#
# You'll likely see HTTP 403 here, not a 5xx - that's correct, not a bug.
# While the site is in the stopped state (from az webapp stop above),
# App Service's front end returns "403 - This web app is stopped" to
# every request. That's actually a more definitive "confirmed down"
# signal than racing a 5xx against container startup timing, since 403
# unambiguously means "explicitly disabled" rather than "up but the
# backend failed."
wait_for_app_health "$HEALTH_URL" false 18 10 || true

echo
echo "== Fix it: restore the correct port =="
az webapp config appsettings set --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" \
  --settings WEBSITES_PORT=8000 --output none
az webapp stop --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"
az webapp start --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Confirm it recovered =="
wait_for_app_health "$HEALTH_URL" true
