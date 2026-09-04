#!/usr/bin/env bash
# Shared variables for LP01/M01 scripts. Edit SUFFIX before running.
set -euo pipefail

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Fires on any exit (success,
# `exit N`, or a set -e abort), not just a clean finish.
source "$(dirname "${BASH_SOURCE[0]}")/../../../../shared/lib/timing.sh"
trap print_elapsed EXIT
SUFFIX="${SUFFIX:-ai200lp01}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp01-container-hosting}"
ACR_NAME="${ACR_NAME:-acr${SUFFIX}}"
IMAGE_NAME="inference-api"
IMAGE_TAG="v1"
APP_DIR="../../../../shared/inference-api"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  LOCATION=$LOCATION  ACR_NAME=$ACR_NAME"
