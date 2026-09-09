#!/usr/bin/env bash
# Slide 34: multiple revision mode + weighted traffic split (canary/blue-green).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh

az containerapp revision set-mode --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --mode multiple

echo "== Current revisions =="
REVISION_COUNT=$(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "length(@)" --output tsv)
if [ "$REVISION_COUNT" -lt 2 ]; then
  echo "Only $REVISION_COUNT revision(s) exist - creating a second one (revision-scope"
  echo "env var change) so there's something to split traffic between."
  az containerapp update --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
    --set-env-vars "IMAGE_VERSION=v2-canary" --output none
fi
az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query "[].{name:name, active:properties.active}" --output table

# Identify which revision is the canary by the trait we actually control
# (the IMAGE_VERSION=v2-canary env var set above), not by position in the
# list - az containerapp revision list's ordering isn't newest-first as
# might be assumed (confirmed the hard way: an earlier version of this
# script used [0]/[1] and ended up applying the weights backwards - the
# pre-existing revision got labeled "latest" and the just-created canary
# got labeled "previous", so the canary ended up with 80% of traffic
# instead of the intended 20%).
CANARY_REVISION=""
STABLE_REVISION=""
for rev in $(az containerapp revision list --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --query "[].name" --output tsv); do
  IMG_VER=$(az containerapp revision show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" --revision "$rev" \
    --query "properties.template.containers[0].env[?name=='IMAGE_VERSION'].value | [0]" --output tsv 2>/dev/null || echo "")
  if [ "$IMG_VER" = "v2-canary" ]; then
    CANARY_REVISION="$rev"
  elif [ -z "$STABLE_REVISION" ]; then
    STABLE_REVISION="$rev"
  fi
done

if [ -z "$CANARY_REVISION" ] || [ -z "$STABLE_REVISION" ]; then
  echo "Could not identify both a canary and a stable revision - check: az containerapp revision list -n $ACA_APP -g $RESOURCE_GROUP" >&2
  exit 1
fi

echo "== 20/80 canary split: $CANARY_REVISION (v2-canary) gets 20%, $STABLE_REVISION gets 80% =="
az containerapp ingress traffic set --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --revision-weight "${CANARY_REVISION}=20" "${STABLE_REVISION}=80" \
  --output table

echo
echo "== Proving the split actually happens: 30 requests, tallied by imageVersion =="
# The /config endpoint on the demo app reports IMAGE_VERSION from its own
# environment - the new revision above set it to "v2-canary", so which
# value comes back tells us which revision actually answered.
FQDN=$(az containerapp show --name "$ACA_APP" --resource-group "$RESOURCE_GROUP" \
  --query properties.configuration.ingress.fqdn --output tsv)
CANARY_HITS=0
OTHER_HITS=0
for i in $(seq 1 300); do
  VERSION=$(curl -s --max-time 10 "https://${FQDN}/config" | python3 -c "import json,sys; print(json.load(sys.stdin).get('imageVersion','?'))" 2>/dev/null || echo "?")
  if [ "$VERSION" = "v2-canary" ]; then
    CANARY_HITS=$((CANARY_HITS + 1))
  else
    OTHER_HITS=$((OTHER_HITS + 1))
  fi
done
echo "canary (v2-canary): $CANARY_HITS/300 requests (~$((CANARY_HITS * 100 / 300))%, configured 20%)"
echo "other:               $OTHER_HITS/300 requests (~$((OTHER_HITS * 100 / 300))%, configured 80%)"
echo "(small sample - expect noise around the configured weights, not an exact match)"
