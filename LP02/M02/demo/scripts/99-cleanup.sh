#!/usr/bin/env bash
# Tears down what THIS module created/modified. Since M02 only updates
# the container app M01 (or this module's own bootstrap) created rather
# than creating separate resources, this deletes the container app
# itself - leaving the environment, ACR, and image in place since other
# modules (and a fresh M01 run) can reuse them.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the container app =="
az containerapp delete --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no container app found)"

echo
echo "Done. Left in place: resource group '$RESOURCE_GROUP', Container Apps environment, ACR, and image."
echo "To remove everything for LP02, run: ../../../99-cleanup-all.sh"
