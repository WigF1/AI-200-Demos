#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

SUFFIX="${SUFFIX:-ai200lp07}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp07-integrate}"
STORAGE_ACCOUNT="st${SUFFIX}"
FUNCTION_APP="func-${SUFFIX}"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  FUNCTION_APP=$FUNCTION_APP"
# Service Bus namespace from LP07/M01 - the queue trigger's source.
SB_NAMESPACE="sb-${SUFFIX}"
JOBS_QUEUE="document-jobs"
