#!/usr/bin/env bash
# Slide 8: scheduled cleanup of untagged images.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

az acr task create --registry "$ACR_NAME" --name cleanup-untagged \
  --cmd "acr purge --filter '${IMAGE_NAME}:.*' --untagged --ago 7d" \
  --schedule "0 0 * * 0" --context /dev/null

az acr task run --registry "$ACR_NAME" --name cleanup-untagged
