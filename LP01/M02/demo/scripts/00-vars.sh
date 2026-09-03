#!/usr/bin/env bash
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp01}"
LOCATION="${LOCATION:-australiaeast}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp01-container-hosting}"
ACR_NAME="${ACR_NAME:-acr${SUFFIX}}"
IMAGE_NAME="inference-api"
IMAGE_TAG="v1"
APP_SERVICE_PLAN="asp-${SUFFIX}"
WEBAPP_NAME="app-${SUFFIX}"
# P0V3 (entry-level Premium v3), not B1 (Basic): 02-configure-app-settings
# creates a staging deployment slot, and Basic tier doesn't support
# deployment slots at all - only Standard, Premium, or Isolated do.
# P0V3 is the cheapest SKU that supports slots and is the current
# Microsoft-recommended default for new deployments (Standard/S1 is the
# older, being-phased-out option at a similar price point). This costs
# meaningfully more than B1 while running - run 99-cleanup.sh promptly
# when you're done. See https://azure.microsoft.com/pricing/details/app-service/linux/
WEBAPP_SKU="P0V3"
STAGING_SLOT_NAME="staging"
KEYVAULT_NAME="kv-${SUFFIX}"
KV_SECRET_NAME="model-api-key"
echo "RESOURCE_GROUP=$RESOURCE_GROUP  WEBAPP_NAME=$WEBAPP_NAME  ACR_NAME=$ACR_NAME"
