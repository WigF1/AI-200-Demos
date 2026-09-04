#!/usr/bin/env bash
# Tears down what THIS module created: the AKS cluster and ACR. Since
# LP03's other modules (M02, M03) all deploy into the same cluster rather
# than owning separate infra, this is effectively the full LP03 teardown
# minus the resource group itself.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the AKS cluster (this takes several minutes) =="
az aks delete --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --yes --no-wait 2>/dev/null \
  || echo "  (no AKS cluster found)"

echo "== Deleting the ACR =="
az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no ACR found)"

echo
echo "AKS deletion was started with --no-wait - it'll finish in the background."
echo "Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too (and not wait on the AKS deletion first), run: ../../../99-cleanup-all.sh"
