#!/usr/bin/env bash
# Tears down what THIS module created: the Service Bus namespace/queue.
# Leaves the container app, environment, and ACR in place since M01/M02
# depend on them. Also resets the container app's scale rules back to a
# single always-on replica so it doesn't sit at 0 or mid-scale-test state.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Resetting scale rules and revision mode =="
az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --min-replicas 1 --max-replicas 3 --output none 2>/dev/null || echo "  (no container app found)"
az containerapp revision set-mode --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --mode single --output none 2>/dev/null || true

echo "== Deleting the Service Bus namespace (includes the queue) =="
az servicebus namespace delete --name "$SERVICEBUS_NAMESPACE" --resource-group "$RESOURCE_GROUP" 2>/dev/null \
  || echo "  (no Service Bus namespace found)"

echo
echo "Done. Left in place: resource group '$RESOURCE_GROUP', container app, environment, ACR."
echo "To remove everything for LP02, run: ../../../99-cleanup-all.sh"
