#!/usr/bin/env bash
# Slide 8: creates the "dangling" untagged manifests that 05-cleanup-untagged
# purges. A fresh ACR has nothing untagged, so the purge task in
# 05-cleanup-untagged has nothing to demonstrate unless we manufacture some
# first - this script does that on purpose, separately, so it can be
# re-run any time to reset the demo.
#
# How an image becomes "untagged": build two throwaway builds under a tag,
# then move that tag onto a newer build. The manifests the tag used to
# point at are still in the registry (still billed, still counted) but no
# tag references them anymore - exactly what `acr purge --untagged` targets.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

SCRATCH_TAG="scratch"

echo "== Build #1 under :$SCRATCH_TAG =="
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${SCRATCH_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none

echo "== Build #2 - moves :$SCRATCH_TAG, orphaning build #1's manifest =="
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${SCRATCH_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none

echo "== Build #3 - moves :$SCRATCH_TAG again, orphaning build #2's manifest =="
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${SCRATCH_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none

echo
echo "== Manifests with no tag pointing at them (untagged) =="
az acr manifest list-metadata --registry "$ACR_NAME" --name "$IMAGE_NAME" \
  --query "[?tags==null || length(tags)==\`0\`].{digest:digest, createdTime:createdTime}" \
  --output table

echo
echo "Seed complete. Run ./05-cleanup-untagged.sh to purge these."
