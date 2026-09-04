#!/usr/bin/env bash
# Makes this module runnable without LP03/M01 having run first. Mirrors
# M01's cluster/ACR creation and base deployment, each step checking
# existence first so this is a fast no-op when M01 already ran. AKS
# cluster creation takes 5-10 minutes if starting cold.
set -euo pipefail

echo "== Ensuring prerequisites for LP03/M02 (ACR, image, AKS cluster, base deployment) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "ACR '$ACR_NAME' already exists."
else
  az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
    --sku Standard --admin-enabled false --output table
fi

if ! az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --output none 2>/dev/null; then
  az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${APP_DIR}/Dockerfile" "$APP_DIR"
fi

if az aks show --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --output none 2>/dev/null; then
  echo "AKS cluster '$AKS_CLUSTER' already exists."
else
  echo "AKS cluster '$AKS_CLUSTER' not found - creating (LP03/M01 likely hasn't run; this takes 5-10 minutes)..."
  az aks create \
    --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
    --node-count 2 --node-vm-size Standard_B2s \
    --generate-ssh-keys \
    --attach-acr "$ACR_NAME" \
    --output table
fi

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl get deployment inference-api -n "$NAMESPACE" --output none 2>/dev/null; then
  echo "Base deployment not found - applying it from LP03/M01's manifests..."
  LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
  sed "s#<ACR_LOGIN_SERVER>#${LOGIN_SERVER}#g" ../../../M01/demo/manifests/deployment.yaml > /tmp/deployment.yaml
  kubectl apply -n "$NAMESPACE" -f /tmp/deployment.yaml
  kubectl apply -n "$NAMESPACE" -f ../../../M01/demo/manifests/service-loadbalancer.yaml
  kubectl apply -n "$NAMESPACE" -f ../../../M01/demo/manifests/service-clusterip.yaml
  kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s \
    || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2
fi

echo "Prerequisites ready."
