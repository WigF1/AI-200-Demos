#!/usr/bin/env bash
# Shared variables for LP01/M01 scripts. Edit SUFFIX before running.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp01}"
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp01-container-hosting}"
ACR_NAME="${ACR_NAME:-acr${SUFFIX}}"
IMAGE_NAME="inference-api"
IMAGE_TAG="v1"
APP_DIR="../../../../shared/inference-api"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  LOCATION=$LOCATION  ACR_NAME=$ACR_NAME"
