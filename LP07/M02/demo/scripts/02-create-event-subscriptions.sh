#!/usr/bin/env bash
# Slide 20, 24: filtered event subscription delivering to the Event Grid
# Viewer deployed by 01-create-eventgrid-topic. Run that first, and have
# the viewer open in a browser BEFORE running this - Event Grid validates
# the endpoint during the create, so the viewer must be awake to answer.
# This topic is CloudEvents, so validation is the CloudEvents webhook
# OPTIONS handshake (WebHook-Request-Origin -> WebHook-Allowed-Origin):
# the viewer answers it but doesn't display it. Only Event Grid-schema
# subscriptions get a POSTed SubscriptionValidation event the viewer shows.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

TOPIC_ID=$(az eventgrid topic show -g "$RESOURCE_GROUP" -n "$EVENTGRID_TOPIC" --query id -o tsv)

echo "== Filtered event subscription: only StringIn data.status = flagged (Slide 24) =="
if az eventgrid event-subscription show --name moderation-flagged-sub --source-resource-id "$TOPIC_ID" \
  --output none 2>/dev/null; then
  echo "Event subscription 'moderation-flagged-sub' already exists."
else
  # The create doesn't return until validation completes - if the viewer
  # is asleep or still starting it fails with a validation error; browse
  # to it, wait for the page to load, and re-run.
  time_step "Event subscription create (includes endpoint validation)" \
    az eventgrid event-subscription create \
    --name moderation-flagged-sub \
    --source-resource-id "$TOPIC_ID" \
    --endpoint-type webhook \
    --endpoint "$VIEWER_ENDPOINT" \
    --advanced-filter data.status StringIn flagged \
    --output table
fi

echo
echo "Subscription delivers to $VIEWER_ENDPOINT"
echo "Run ../python/publish_events.py and watch https://${VIEWER_SITE}.azurewebsites.net"
