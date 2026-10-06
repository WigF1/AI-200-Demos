#!/usr/bin/env bash
# Slide 18, 22: custom topic with CloudEvents v1.0 input schema, plus the
# Event Grid Viewer web app that 02-create-event-subscriptions points at.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az eventgrid topic show --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --output none 2>/dev/null; then
  echo "Event Grid topic '$EVENTGRID_TOPIC' already exists."
else
  az eventgrid topic create \
    --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --location "$LOCATION" \
    --input-schema cloudeventschemav1_0 \
    --output table
fi

echo "== Event Grid Viewer web app: the subscriptions' webhook handler =="
# Microsoft's sample viewer, deployed from its own ARM template: an App
# Service plan + web app built from the GitHub repo. It shows every
# request Event Grid POSTs to /api/updates live in the browser (SignalR).
# NOT re-runnable: redeploying fails with "Conflict with existing ScmType:
# ExternalGit" (the template's sourcecontrols resource can't be re-PUT),
# so skip it once the web app exists. The deployment returns only after
# the app has been built from the repo.
if az webapp show --resource-group "$RESOURCE_GROUP" --name "$VIEWER_SITE" --output none 2>/dev/null; then
  echo "Event Grid Viewer web app '$VIEWER_SITE' already exists."
else
  time_step "Event Grid Viewer deploy (builds the app from GitHub)" \
    az deployment group create \
    --resource-group "$RESOURCE_GROUP" --name evgviewer \
    --template-uri "$VIEWER_TEMPLATE_URI" \
    --parameters siteName="$VIEWER_SITE" hostingPlanName="$VIEWER_PLAN" sku="$VIEWER_SKU" location="$LOCATION" \
    --output none
fi

echo
echo "== Topic endpoint and key for the Python publisher =="
ENDPOINT=$(az eventgrid topic show --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query endpoint --output tsv)
KEY=$(az eventgrid topic key list --resource-group "$RESOURCE_GROUP" --name "$EVENTGRID_TOPIC" --query key1 --output tsv)
echo "export EVENTGRID_TOPIC_ENDPOINT=\"$ENDPOINT\""
echo "export EVENTGRID_TOPIC_KEY=\"$KEY\""
echo "(paste the two lines above into your shell before running the Python demos)"

echo
echo "== NEXT: open the viewer BEFORE creating any subscriptions =="
echo "  1. Browse to https://${VIEWER_SITE}.azurewebsites.net and wait for the page to load."
echo "     F1 apps sleep when idle - the first request can take 30s+ to wake it."
echo "  2. Keep that tab open, then run ./02-create-event-subscriptions.sh"
echo "     Event Grid validates the endpoint as the subscription is created, so the"
echo "     viewer must already be awake to answer, or the create fails."
echo "     This topic is CloudEvents, so validation is an HTTP OPTIONS handshake"
echo "     (WebHook-Request-Origin -> WebHook-Allowed-Origin) that the viewer answers"
echo "     without displaying it. Only Event Grid-schema subscriptions get a visible"
echo "     SubscriptionValidation event. The subscription succeeding is the proof"
echo "     the handshake worked; published events then appear in the viewer live."
