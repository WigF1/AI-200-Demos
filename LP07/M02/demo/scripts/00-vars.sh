#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
EVENTGRID_TOPIC="evgt-${SUFFIX}"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  EVENTGRID_TOPIC=$EVENTGRID_TOPIC"
