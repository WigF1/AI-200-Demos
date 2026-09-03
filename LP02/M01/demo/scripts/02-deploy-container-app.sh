#!/usr/bin/env bash
# Slide 7-9: containerapp create, managed identity + AcrPull, env vars/secrets.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)
IMAGE_REF="${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "== Create the container app with a system-assigned identity and a secret =="
az containerapp create \
  --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --environment "$ACA_ENV" \
  --image "$IMAGE_REF" \
  --target-port 8000 --ingress external \
  --registry-server "$LOGIN_SERVER" --registry-identity system \
  --system-assigned \
  --secrets "model-api-key=demo-api-key-not-real-1234567890" \
  --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" \
             "MODEL_API_KEY=secretref:model-api-key" \
  --min-replicas 1 --max-replicas 3 \
  --output table

PRINCIPAL_ID=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query identity.principalId --output tsv)
ACR_ID=$(az acr show --name "$ACR_NAME" --query id --output tsv)
az role assignment create --assignee "$PRINCIPAL_ID" --scope "$ACR_ID" --role "AcrPull"

echo "== App URL =="
az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv
