#!/usr/bin/env bash
# Slide 8: reproduce and diagnose ImagePullBackOff (registry path or pull
# access issue). Same pause/portal-guidance pattern as
# 03-troubleshoot-common-failures.sh.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh
source ./00-ensure-prereqs.sh
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$AKS_CLUSTER" --overwrite-existing 2>/dev/null || true

pause() {
  local message="${1:-Press Enter to continue...}"
  if [ -t 0 ]; then
    read -r -p "$message " _
  else
    echo "$message (non-interactive shell detected - continuing automatically)"
  fi
}

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

cat <<TXT
ImagePullBackOff: the node can't pull the container image - wrong tag,
wrong repository, or missing pull access are the usual causes.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource ->
     Kubernetes resources -> Workloads -> inference-api, and note all 3
     Pods are Running with the current image tag.
  2. AFTER the break (Portal): refresh Workloads and watch the Pod
     status column cycle through ErrImagePull -> ImagePullBackOff.
  3. DURING diagnosis (this script also runs this): kubectl describe pod
     shows the exact pull failure in Events - e.g. "manifest for
     ...:does-not-exist not found" - which tells you immediately whether
     it's a bad tag, a bad repo name, or an auth problem, without
     needing to guess.
  4. AFTER the fix (Portal or CLI): refresh Workloads / kubectl get pods
     to confirm all 3 Pods return to Running with the correct image.
TXT
pause "Ready to break it?"

echo "== Break: point the deployment at a tag that doesn't exist =="
kubectl set image deployment/inference-api inference-api="${LOGIN_SERVER}/inference-api:does-not-exist" -n "$NAMESPACE"

pause "Image reference is now broken - good point to check the Portal Workloads page before continuing."

echo "== Observe: Pod status cycling through ErrImagePull / ImagePullBackOff (waits up to 60s) =="
for attempt in $(seq 1 6); do
  kubectl get pods -n "$NAMESPACE" -l app=inference-api
  STATUS_MATCH=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api \
    -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || echo "")
  if echo "$STATUS_MATCH" | grep -qE "ImagePullBackOff|ErrImagePull"; then
    break
  fi
  sleep 10
done

pause "Pods should show ImagePullBackOff/ErrImagePull above. Ready to diagnose?"

echo "== Diagnose: describe a Pod and read the exact pull error in Events =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n "$NAMESPACE" | tail -20

pause "The exact pull failure reason should be visible above. Ready to fix it?"

echo "== Fix: restore the correct image tag =="
kubectl set image deployment/inference-api inference-api="${LOGIN_SERVER}/inference-api:v1" -n "$NAMESPACE"
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s \
  || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2

echo
echo "Fixed - all 3 Pods should be Running again. Refresh the Portal Workloads page (step 4 above) to confirm."
