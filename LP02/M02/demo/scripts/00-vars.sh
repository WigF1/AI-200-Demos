#!/usr/bin/env bash
set -euo pipefail
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
echo "RESOURCE_GROUP=$RESOURCE_GROUP  ACA_APP=$ACA_APP"
