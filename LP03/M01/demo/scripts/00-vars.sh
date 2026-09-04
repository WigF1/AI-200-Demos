#!/usr/bin/env bash
set -euo pipefail

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Fires on any exit (success,
# `exit N`, or a set -e abort), not just a clean finish.
source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT
SUFFIX="${SUFFIX:-ai200lp03}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp03-aks}"
ACR_NAME="${ACR_NAME:-acr${SUFFIX}}"
AKS_CLUSTER="aks-${SUFFIX}"
IMAGE_NAME="inference-api"
IMAGE_TAG="v1"
APP_DIR="../../../../shared/inference-api"
NAMESPACE="ai-workloads"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  AKS_CLUSTER=$AKS_CLUSTER  ACR_NAME=$ACR_NAME"
