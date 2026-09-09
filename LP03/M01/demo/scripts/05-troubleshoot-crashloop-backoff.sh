#!/usr/bin/env bash
# Slide 8: reproduce and diagnose CrashLoopBackOff (app starts, then
# exits or fails health checks). Same pause/portal-guidance pattern as
# 03-troubleshoot-common-failures.sh. Uses the same FORCE_CRASH_DEMO
# mechanism as LP03/M03/02-break-and-diagnose.sh (that script covers the
# Module 3 monitoring angle on the same failure; this one is the Module
# 1 "recognize the four signals" angle).
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

cat <<'TXT'
CrashLoopBackOff: the container starts, then exits (or fails its
liveness probe) repeatedly - the platform backs off between restarts.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource ->
     Kubernetes resources -> Workloads -> inference-api, and note the
     Restarts column reads 0 for all 3 Pods.
  2. AFTER the break (Portal): refresh Workloads and watch Restarts
     climb and the status cycle Running -> CrashLoopBackOff.
  3. DURING diagnosis (this script also runs this): kubectl logs
     --previous reads the crashed container's own output directly -
     usually faster than describe/Events for an application-level
     crash, since the app's own error message is right there.
  4. AFTER the fix (Portal or CLI): refresh Workloads to confirm Restarts
     stop climbing and every Pod is back to Running.
TXT
pause "Ready to break it?"

echo "== Break: set FORCE_CRASH_DEMO=true so the container exits on startup =="
kubectl set env deployment/inference-api -n "$NAMESPACE" FORCE_CRASH_DEMO=true

pause "Crash flag is now set - good point to check the Portal Workloads page before continuing."

echo "== Observe: restart count climbing, status cycling toward CrashLoopBackOff (waits up to 60s) =="
for attempt in $(seq 1 6); do
  kubectl get pods -n "$NAMESPACE" -l app=inference-api
  STATUS_MATCH=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api \
    -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || echo "")
  if echo "$STATUS_MATCH" | grep -q "CrashLoopBackOff"; then
    break
  fi
  sleep 10
done

pause "Pods should show climbing restarts / CrashLoopBackOff above. Ready to diagnose?"

echo "== Diagnose: read the crashed container's own logs (faster than Events for an app-level crash) =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n "$NAMESPACE" --previous --tail=20 \
  || echo "  (no previous container yet - it may still be on its first crash; re-run this line in a few seconds)"
echo
echo "== Events, for comparison =="
kubectl describe pod "$POD" -n "$NAMESPACE" | tail -15

pause "The app's own crash message should be visible above. Ready to fix it?"

echo "== Fix: remove the crash flag =="
kubectl set env deployment/inference-api -n "$NAMESPACE" FORCE_CRASH_DEMO-
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s \
  || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2

echo
echo "Fixed - restarts should stop climbing and all 3 Pods return to Running. Refresh the Portal Workloads page (step 4 above) to confirm."
