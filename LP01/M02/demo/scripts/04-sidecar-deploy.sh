#!/usr/bin/env bash
# Lab 03 (03-app-svc-sidecar.md): add a sidecar container to the app
# created in 01-deploy-app-service.sh.
#
# Sidecars run in the same App Service site unit as the main container,
# share the same network namespace (reachable via localhost:<port> from
# the main app), and share app settings as env vars unless explicitly
# excluded. Docs: https://learn.microsoft.com/en-us/azure/app-service/overview-sidecar
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Convert the app to sidecar-enabled (sitecontainers) mode =="
az webapp sitecontainers convert \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --mode sitecontainers

echo "== Write a spec file for a small public 'sidecar' image (busybox log-tailer stand-in) =="
cat > /tmp/sidecar-spec.json <<JSON
[
  {
    "containerName": "log-forwarder",
    "image": "mcr.microsoft.com/appsvc/docs/sidecars/sample-experiment:otel-appinsights-1.0",
    "isMain": false,
    "authType": "Anonymous",
    "startUpCommand": "",
    "targetPort": "",
    "volumeMounts": [],
    "environmentVariables": []
  }
]
JSON

echo "== Add the sidecar alongside the existing main container =="
az webapp sitecontainers create \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sitecontainers-spec-file /tmp/sidecar-spec.json

echo "== List containers on the app (main + sidecar) =="
az webapp sitecontainers list \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output table

echo "== Restart so the sidecar starts, then check the log stream for its startup lines =="
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

cat <<'TXT'

Talk track:
  - The main container ("inference-api") and the sidecar share localhost.
    If the sidecar listened on port 4318, the main app could reach it at
    localhost:4318 without any extra networking config.
  - App Service still routes external traffic ONLY to the container
    flagged isMain=true - the sidecar is invisible to the internet.
  - Up to 9 sidecars are supported per Linux app.
  - Roll back with:
      az webapp sitecontainers delete --name $WEBAPP_NAME -g $RESOURCE_GROUP --container-name log-forwarder
      az webapp sitecontainers convert --name $WEBAPP_NAME -g $RESOURCE_GROUP --mode docker
TXT
