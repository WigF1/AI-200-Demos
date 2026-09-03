#!/usr/bin/env bash
# Makes this module runnable on its own, without LP01/M01 having run
# first. Mirrors what M01's 01-create-acr.sh and 02-build-push-acr-task.sh
# do, but each step first checks whether the resource already exists so
# that running this after M01 (the normal path) is a fast no-op, while
# running it cold still gets you a working ACR + pushed image.
#
# Sourced automatically by every other script in this module - you don't
# need to run it directly, though it's safe to.
set -euo pipefail

echo "== Ensuring prerequisites for LP01/M02 (resource group, ACR, ${IMAGE_NAME}:${IMAGE_TAG}) =="

if az group show --name "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "Resource group '$RESOURCE_GROUP' already exists."
else
  echo "Creating resource group '$RESOURCE_GROUP'..."
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --output none 2>/dev/null; then
  echo "ACR '$ACR_NAME' already exists."
else
  echo "Creating ACR '$ACR_NAME' (not found - LP01/M01 likely hasn't run)..."
  az acr create --resource-group "$RESOURCE_GROUP" --name "$ACR_NAME" \
    --sku Standard --admin-enabled false --output table
fi

if az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --output none 2>/dev/null; then
  echo "Image '${IMAGE_NAME}:${IMAGE_TAG}' already in '$ACR_NAME'."
else
  echo "Building and pushing '${IMAGE_NAME}:${IMAGE_TAG}' (not found - LP01/M01 likely hasn't run)..."
  az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none
fi

echo "Prerequisites ready."
