#!/usr/bin/env bash
set -euo pipefail

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Fires on any exit (success,
# `exit N`, or a set -e abort), not just a clean finish.
source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT

# Fail fast (before wasting minutes on AKS cluster creation, or anything
# else) if kubectl isn't installed - az CLI doesn't install it for you.
if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found. Install it with: az aks install-cli" >&2
  echo "(or via your OS package manager: https://kubernetes.io/docs/tasks/tools/)" >&2
  exit 1
fi
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
