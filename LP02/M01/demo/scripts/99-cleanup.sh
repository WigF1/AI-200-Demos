#!/usr/bin/env bash
# Tears down what THIS module created: the container app, Container Apps
# environment, Log Analytics workspace, and ACR. Since LP02 only has M01-
# M03 all sharing one environment/ACR (no later module solely owns them),
# this is effectively the full LP02 teardown minus the resource group
# itself - equivalent to running 99-cleanup-all.sh, but keeps the RG in
# case you're using it for something else.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Deleting the container app =="
az containerapp delete --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no container app found)"

echo "== Deleting the Container Apps environment =="
az containerapp env delete --name "$ACA_ENV" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no environment found)"

echo "== Deleting the Log Analytics workspace =="
az monitor log-analytics workspace delete --resource-group "$RESOURCE_GROUP" \
  --workspace-name "$LOG_ANALYTICS_WORKSPACE" --yes --force true 2>/dev/null \
  || echo "  (no workspace found)"

echo "== Deleting the ACR =="
az acr delete --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --yes 2>/dev/null \
  || echo "  (no ACR found)"

echo
echo "Done. Resource group '$RESOURCE_GROUP' itself was left in place."
echo "To remove it too, run: ../../../99-cleanup-all.sh"
