#!/usr/bin/env bash
# Slide 8: scheduled cleanup of untagged images.
# Run 04-seed-untagged-images.sh first if you want real matches to purge -
# a brand-new ACR has nothing untagged, so the task would otherwise run
# and report zero deleted images.
#
# --filter uses a tag regex ("${IMAGE_NAME}:^$") that can never match a
# real tag - it only matches an empty string. --untagged is additive, not
# restrictive: it deletes manifests matching the tag regex AND any manifest
# with no tag at all. An unmatchable regex means only the second part
# (dangling, untagged manifests) ever fires, so "latest" and "scratch"
# stay untouched. A broader regex like ".*" would ALSO delete every tag
# it matches once --ago's window makes them eligible - it worked in this
# demo because the slide's --ago 7d protected anything recently pushed,
# not because the regex only targeted untagged images.
#
# --ago 0d (not the slide's 7d) is deliberate for this demo: --ago 7d only
# purges manifests older than 7 days, so anything 04-seed-untagged-images.sh
# just created would be silently skipped and the effect wouldn't be visible.
# In production, keep --ago 7d (or longer) so you don't race an in-flight
# push that hasn't been re-tagged yet.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Untagged manifests before purge =="
BEFORE_COUNT=$(az acr manifest list-metadata --registry "$ACR_NAME" --name "$IMAGE_NAME" \
  --query "length([?tags==null || length(tags)==\`0\`])" --output tsv)
echo "Untagged manifest count: $BEFORE_COUNT"
if [ "$BEFORE_COUNT" = "0" ]; then
  echo "Nothing to purge yet - run ./04-seed-untagged-images.sh first to see this task actually delete something."
fi

az acr task create --registry "$ACR_NAME" --name cleanup-untagged \
  --cmd "acr purge --filter '${IMAGE_NAME}:^\$' --untagged --ago 0d" \
  --schedule "0 0 * * 0" --context /dev/null \
  --output none 2>/dev/null || \
az acr task update --registry "$ACR_NAME" --name cleanup-untagged \
  --cmd "acr purge --filter '${IMAGE_NAME}:^\$' --untagged --ago 0d" \
  --schedule "0 0 * * 0" --context /dev/null --output none

echo "== Running the purge task now (normally fires on the weekly schedule) =="
az acr task run --registry "$ACR_NAME" --name cleanup-untagged

echo
echo "== Confirming tagged images survived (latest, v1, scratch if present) =="
az acr repository show-tags --name "$ACR_NAME" --repository "$IMAGE_NAME" --output table

echo
echo "== Untagged manifests after purge =="
AFTER_COUNT=$(az acr manifest list-metadata --registry "$ACR_NAME" --name "$IMAGE_NAME" \
  --query "length([?tags==null || length(tags)==\`0\`])" --output tsv)
echo "Untagged manifest count: $AFTER_COUNT (was $BEFORE_COUNT)"
