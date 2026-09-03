#!/usr/bin/env bash
# Slide 5: managed Kubernetes control plane on Azure; attach ACR for pulls.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table

az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
  --sku Standard --admin-enabled false --output table
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR"

echo "== Create a small AKS cluster (2 nodes, B2s) for the demo =="
az aks create \
  --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" \
  --node-count 2 --node-vm-size Standard_B2s \
  --generate-ssh-keys \
  --attach-acr "$ACR_NAME" \
  --output table

az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing

echo "== ACR login server to substitute into the manifests =="
az acr show --name "$ACR_NAME" --query loginServer --output tsv

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
