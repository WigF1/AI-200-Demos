#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
EVENTGRID_TOPIC="evgt-${SUFFIX}"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  EVENTGRID_TOPIC=$EVENTGRID_TOPIC"
# Event Grid Viewer sample (github.com/Azure-Samples/azure-event-grid-viewer)
# - the webhook handler the event subscriptions deliver to. Site name is
# global (<name>.azurewebsites.net), hence the suffix.
VIEWER_SITE="evgviewer-${SUFFIX}"
VIEWER_PLAN="asp-evgviewer-${SUFFIX}"
VIEWER_SKU="${VIEWER_SKU:-F1}"
VIEWER_TEMPLATE_URI="https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/main/azuredeploy.json"
VIEWER_ENDPOINT="https://${VIEWER_SITE}.azurewebsites.net/api/updates"
