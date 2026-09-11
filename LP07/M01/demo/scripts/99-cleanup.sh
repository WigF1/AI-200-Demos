#!/usr/bin/env bash
# Tears down what THIS module created: the Service Bus namespace (queue,
# topic, and subscriptions all go with it).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the Service Bus namespace =="
az servicebus namespace delete --resource-group "$RESOURCE_GROUP" --name "$SB_NAMESPACE" 2>/dev/null \
  || echo "  (no Service Bus namespace found)"

echo
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../99-cleanup-all.sh"
