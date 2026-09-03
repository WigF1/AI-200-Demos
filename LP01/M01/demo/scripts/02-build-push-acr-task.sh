#!/usr/bin/env bash
# Slide 7: ACR Tasks quick build — cloud build, no local Docker needed.
# Answers Module 1 knowledge check Q1 (inconsistent local builds).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az acr build --registry "$ACR_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" --image "${IMAGE_NAME}:latest" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR"

az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output table
