#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp06}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp06-redis}"
REDIS_NAME="redis-${SUFFIX}"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  REDIS_NAME=$REDIS_NAME"
