#!/usr/bin/env bash
# Tears down what THIS module created: the Event Grid topic (its event
# subscription goes with it) and the Event Grid Viewer web app + plan.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the Event Grid topic =="
az eventgrid topic delete --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" 2>/dev/null \
  || echo "  (no Event Grid topic found)"

echo "== Deleting the Event Grid Viewer web app and its App Service plan =="
az webapp delete --resource-group "$RESOURCE_GROUP" --name "$VIEWER_SITE" 2>/dev/null \
  || echo "  (no viewer web app found)"
az appservice plan delete --resource-group "$RESOURCE_GROUP" --name "$VIEWER_PLAN" --yes 2>/dev/null \
  || echo "  (no viewer App Service plan found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
