#!/usr/bin/env bash
# Tears down what THIS module created: the Event Grid topic (its event
# subscription goes with it).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the Event Grid topic =="
az eventgrid topic delete --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" 2>/dev/null \
  || echo "  (no Event Grid topic found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
