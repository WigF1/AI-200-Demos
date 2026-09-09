#!/usr/bin/env bash
# Tears down what THIS module created: the ConfigMap, Secret, PVC, and
# reverts the deployment to the base (unconfigured) version. Leaves the
# AKS cluster and ACR in place since M01/M03 depend on them.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing 2>/dev/null || true

echo "== Deleting ConfigMap, Secret, PVC =="
kubectl delete configmap inference-api-config -n "$NAMESPACE" 2>/dev/null || echo "  (no ConfigMap found)"
kubectl delete secret inference-api-secret -n "$NAMESPACE" 2>/dev/null || echo "  (no Secret found)"
kubectl delete pvc inference-api-data -n "$NAMESPACE" 2>/dev/null || echo "  (no PVC found)"

echo "== Deleting Key Vault CSI integration resources (03-keyvault-csi-integration.sh) =="
# The SecretProviderClass must be deleted BEFORE disabling the add-on -
# Microsoft's own docs note that disabling with one still in use errors out.
kubectl delete secretproviderclass "$SECRET_PROVIDER_CLASS" -n "$NAMESPACE" 2>/dev/null \
  || echo "  (no SecretProviderClass found)"
kubectl delete secret "$SYNCED_SECRET_NAME" -n "$NAMESPACE" 2>/dev/null \
  || echo "  (no synced secret found)"
az aks disable-addons --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
  --addons azure-keyvault-secrets-provider --output none 2>/dev/null \
  || echo "  (add-on already disabled or never enabled)"
if az keyvault show --name "$KEYVAULT_NAME" --output none 2>/dev/null; then
  az keyvault delete --name "$KEYVAULT_NAME" --output none
  az keyvault purge --name "$KEYVAULT_NAME" --location "$LOCATION" --output none 2>/dev/null \
    || echo "  (nothing to purge)"
else
  echo "  (no Key Vault found)"
fi

echo
echo "Done. Left in place: AKS cluster, ACR, namespace, and the base deployment/services."
echo "To remove everything for LP03, run: ../../../99-cleanup-all.sh"
