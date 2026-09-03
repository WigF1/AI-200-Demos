#!/usr/bin/env bash
# Slide 8: shows the actual EFFECT of --write-enabled false set in
# 03-tag-version-lock.sh. Setting the flag is invisible on its own -
# this script proves it by trying to overwrite and then delete the locked
# tag, expecting both to fail, then unlocks and repeats to show they
# succeed once the lock is removed.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Confirm the tag is currently locked =="
az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --query "changeableAttributes" --output json

echo
echo "== Attempt 1: overwrite the locked tag with a new build (expected to FAIL) =="
if az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
     --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none 2>/tmp/overwrite-attempt.log; then
  echo "UNEXPECTED: overwrite succeeded - the tag was not actually locked."
else
  echo "Blocked, as expected. ACR's response:"
  tail -n 5 /tmp/overwrite-attempt.log
fi

echo
echo "== Attempt 2: delete the locked tag (expected to FAIL) =="
if az acr repository delete --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --yes 2>/tmp/delete-attempt.log; then
  echo "UNEXPECTED: delete succeeded - the tag was not actually locked."
else
  echo "Blocked, as expected. ACR's response:"
  tail -n 5 /tmp/delete-attempt.log
fi

echo
echo "== Unlock the tag =="
az acr repository update --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --write-enabled true
az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --query "changeableAttributes" --output json

echo
echo "== Attempt 3: overwrite again now that it's unlocked (expected to SUCCEED) =="
az acr build --registry "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --file "${APP_DIR}/Dockerfile" "$APP_DIR" --output none
echo "Succeeded - the tag now points at a new manifest."

echo
echo "== Re-lock it, since 03-tag-version-lock.sh's whole point was production protection =="
az acr repository update --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" --write-enabled false
az acr repository show --name "$ACR_NAME" --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  --query "changeableAttributes" --output json
