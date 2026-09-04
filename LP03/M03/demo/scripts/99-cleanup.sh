#!/usr/bin/env bash
# Tears down what THIS module modified: reverts the FORCE_CRASH_DEMO env
# var if it was left set. Leaves the AKS cluster, ACR, and deployments in
# place since M01/M02 depend on them.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing 2>/dev/null || true

echo "== Removing FORCE_CRASH_DEMO if it was left set =="
kubectl set env deployment/inference-api -n "$NAMESPACE" FORCE_CRASH_DEMO- 2>/dev/null || true

echo
echo "Done. Left in place: AKS cluster, ACR, namespace, and deployments."
echo "To remove everything for LP03, run: ../../../99-cleanup-all.sh"
