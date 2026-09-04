#!/usr/bin/env bash
set -euo pipefail

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Fires on any exit (success,
# `exit N`, or a set -e abort), not just a clean finish.
source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT
SUFFIX="${SUFFIX:-ai200lp02}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp02-container-apps}"
ACR_NAME="${ACR_NAME:-acr${SUFFIX}}"
IMAGE_NAME="inference-api"
IMAGE_TAG="v1"
APP_DIR="../../../../shared/inference-api"
ACA_ENV="env-${SUFFIX}"
ACA_APP="aca-${SUFFIX}"
LOG_ANALYTICS_WORKSPACE="law-${SUFFIX}"
SERVICEBUS_NAMESPACE="${SERVICEBUS_NAMESPACE:-sb-${SUFFIX}}"
SERVICEBUS_QUEUE="${SERVICEBUS_QUEUE:-inference-requests}"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  ACA_APP=$ACA_APP"
