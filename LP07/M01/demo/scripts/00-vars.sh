#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
SB_NAMESPACE="sb-${SUFFIX}"
QUEUE_NAME="inference-requests"
TOPIC_NAME="inference-results"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  SB_NAMESPACE=$SB_NAMESPACE"
