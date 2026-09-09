#!/usr/bin/env bash
# Slide 8: reproduce and diagnose Pending (resource requests exceed
# available node capacity). Same pause/portal-guidance pattern as
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

# These match deployment.yaml exactly, so "fix" restores the real
# original values rather than an approximation.
ORIGINAL_CPU_REQUEST="100m"
ORIGINAL_MEM_REQUEST="128Mi"

cat <<'TXT'
Pending: the scheduler can't find a node with enough free CPU/memory to
satisfy the Pod's resource requests, so it never gets placed at all.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource -> Node
     pools (or Kubernetes resources -> Nodes), and note how much
     allocatable CPU/memory each node reports.
  2. AFTER the break (Portal): refresh Kubernetes resources -> Workloads
     and watch a new Pod sit in Pending indefinitely - unlike the other
     three failure signals, it never even reaches "Running" once to
     then fail; it's stuck before scheduling.
  3. DURING diagnosis (this script also runs this): kubectl describe pod
     shows a FailedScheduling event with the exact shortfall (e.g.
     "0/2 nodes are available: 2 Insufficient cpu") - the cleanest
     evidence this is a capacity problem, not an app problem.
  4. AFTER the fix (Portal or CLI): refresh Workloads to confirm the
     Pod moves from Pending to Running once requests are realistic again.
TXT
pause "Ready to break it?"

echo "== Break: request 100 CPU cores per replica (no node in this cluster has that much) =="
kubectl set resources deployment/inference-api -n "$NAMESPACE" --containers=inference-api --requests=cpu=100

pause "Resource request is now unsatisfiable - good point to check the Portal Node pools page before continuing."

echo "== Observe: new Pod(s) stuck Pending (waits up to 60s) =="
for attempt in $(seq 1 6); do
  kubectl get pods -n "$NAMESPACE" -l app=inference-api
  PENDING_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api \
    --field-selector=status.phase=Pending -o name | wc -l)
  if [ "$PENDING_COUNT" -gt 0 ]; then
    break
  fi
  sleep 10
done

pause "At least one Pod should show Pending above. Ready to diagnose?"

echo "== Diagnose: describe the Pending Pod and read the FailedScheduling event =="
PENDING_POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api \
  --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}')
if [ -n "$PENDING_POD" ]; then
  kubectl describe pod "$PENDING_POD" -n "$NAMESPACE" | tail -15
else
  echo "  (no Pending Pod found by name - list above should still show the phase)"
fi

pause "The exact capacity shortfall should be visible above. Ready to fix it?"

echo "== Fix: restore the real resource requests from deployment.yaml =="
kubectl set resources deployment/inference-api -n "$NAMESPACE" --containers=inference-api \
  --requests="cpu=${ORIGINAL_CPU_REQUEST},memory=${ORIGINAL_MEM_REQUEST}"
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s \
  || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2

echo
echo "Fixed - the Pending Pod should now schedule and run. Refresh the Portal Workloads page (step 4 above) to confirm."
