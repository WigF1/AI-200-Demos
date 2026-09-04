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
source ./00-ensure-prereqs.sh
source ../../../../shared/lib/app-health.sh

if ! az webapp show --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" --output none 2>/dev/null; then
  echo "Web app '$WEBAPP_NAME' not found. Run ./01-deploy-app-service.sh first." >&2
  exit 1
fi

echo "== Convert the app to sidecar-enabled (sitecontainers) mode =="
# --yes suppresses the interactive "are you sure?" confirmation prompt
# this command shows by default. Without it, the prompt (along with any
# way to see or answer it) was going to /dev/null while the command sat
# waiting on stdin forever - looks like a hang, isn't actually one.
az webapp sitecontainers convert \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --mode sitecontainers --yes || echo "  (already in sitecontainers mode, or nothing to convert - see any error above)"

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

# az webapp sitecontainers create isn't idempotent either - it has a
# separate 'update' command for a reason. Simplest re-run-safe approach:
# delete the sidecar first if it's already there, then create fresh from
# the spec file.
if az webapp sitecontainers show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
     --container-name log-forwarder --output none 2>/dev/null; then
  echo "Sidecar 'log-forwarder' already exists - removing so it can be recreated cleanly from the spec file."
  az webapp sitecontainers delete --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
    --container-name log-forwarder --output none
fi

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

echo "== Restart so the sidecar starts =="
az webapp restart --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME"

echo "== Verify the main app still serves traffic with the sidecar attached =="
HOSTNAME=$(az webapp show -g "$RESOURCE_GROUP" -n "$WEBAPP_NAME" --query defaultHostName -o tsv)
wait_for_app_health "https://${HOSTNAME}/health" true || true

echo
echo "== Streaming logs for 15s to catch the sidecar's startup lines =="
timeout 15 az webapp log tail --resource-group "$RESOURCE_GROUP" --name "$WEBAPP_NAME" || true

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
      az webapp sitecontainers convert --name $WEBAPP_NAME -g $RESOURCE_GROUP --mode docker --yes
TXT
