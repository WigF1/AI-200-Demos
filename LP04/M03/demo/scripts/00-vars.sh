#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp04}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp04-cosmosdb}"
COSMOS_ACCOUNT="cosmos-${SUFFIX}"
DATABASE_NAME="ragstore"
CONTAINER_NAME="documents"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  COSMOS_ACCOUNT=$COSMOS_ACCOUNT  CONTAINER_NAME=$CONTAINER_NAME"
