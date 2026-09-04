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

echo "== Write a spec file for a small public sidecar image =="
# Schema confirmed against: az webapp sitecontainers create --help (top-level
# "name" + "properties" wrapper).
#
# Image: this used to be mcr.microsoft.com/appsvc/docs/sidecars/sample-
# experiment:otel-appinsights-1.0 (also from Microsoft's own docs, as a
# "public image" schema example) - but that image is a real OpenTelemetry
# Collector pre-configured to export to Azure Monitor, and it refuses to
# start at all without an Application Insights connection string:
#   Error: failed to build pipelines: failed to create "azuremonitor"
#   exporter for data type "logs": ConnectionString and InstrumentationKey
#   cannot be empty
# It crash-looped (confirmed via `az webapp sitecontainers status`:
# Status=Terminated, ExitCode=1, RunCount=3) and appeared to take the
# whole site down with it, not just itself - main + sidecars share one
# site-unit lifecycle, so a crash-looping sidecar can make the otherwise-
# healthy main container unreachable too.
#
# mcr.microsoft.com/appsvc/staticsite:latest is Microsoft's OTHER public-
# image example from the same docs, used there as a full isMain
# replacement - a plain static web server with no external dependencies,
# nothing to crash on.
cat > /tmp/sidecar-spec.json <<JSON
[
  {
    "name": "$SIDECAR_NAME",
    "properties": {
      "image": "mcr.microsoft.com/appsvc/staticsite:latest",
      "isMain": false,
      "authType": "Anonymous",
      "targetPort": "80",
      "volumeMounts": [],
      "environmentVariables": []
    }
  }
]
JSON

# az webapp sitecontainers create isn't idempotent either - it has a
# separate 'update' command for a reason. Simplest re-run-safe approach:
# delete the sidecar first if it's already there, then create fresh from
# the spec file.
if az webapp sitecontainers show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
     --container-name "$SIDECAR_NAME" --output none 2>/dev/null; then
  echo "Sidecar '$SIDECAR_NAME' already exists - removing so it can be recreated cleanly from the spec file."
  az webapp sitecontainers delete --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
    --container-name "$SIDECAR_NAME" --output none
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
echo "== Sidecar status (this is what actually answers 'did it start?' - az webapp log tail only streams the MAIN container's logs, never a sidecar's) =="
# Not filtering with --query here: the exact field name in this command's
# JSON output isn't confirmed against documentation (no example schema
# available), so showing the full object is the honest choice rather than
# guessing a field name that might not exist. Look for "Status": "Running"
# - "Terminated" with a non-zero ExitCode means it crashed, same as the
# OTel image above did.
sleep 10
az webapp sitecontainers status --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
  --container-name "$SIDECAR_NAME" --output json || echo "  (status not available yet - try again in a few seconds)"

echo
echo "== Sidecar's own startup logs (the container-specific equivalent of 'log tail') =="
az webapp sitecontainers log --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" \
  --container-name "$SIDECAR_NAME" || echo "  (no logs yet - the sidecar may still be starting; re-run: az webapp sitecontainers log --name $WEBAPP_NAME -g $RESOURCE_GROUP --container-name $SIDECAR_NAME)"

cat <<TXT

Talk track:
  - The main container ("main") and the sidecar ("$SIDECAR_NAME") share
    localhost. This sidecar listens on port 80, so the main app could
    reach it at localhost:80 without any extra networking config.
  - App Service still routes external traffic ONLY to the container
    flagged isMain=true - the sidecar is invisible to the internet.
  - Up to 9 sidecars are supported per Linux app.
  - A crash-looping sidecar can take the whole site down, not just
    itself - main + sidecars share one site-unit lifecycle. Always
    check "az webapp sitecontainers status" for a new sidecar image
    before assuming a main-app outage is unrelated to it.
  - Roll back with:
      az webapp sitecontainers delete --name $WEBAPP_NAME -g $RESOURCE_GROUP --container-name $SIDECAR_NAME
      az webapp sitecontainers convert --name $WEBAPP_NAME -g $RESOURCE_GROUP --mode docker --yes
TXT
