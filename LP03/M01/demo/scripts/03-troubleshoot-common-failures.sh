#!/usr/bin/env bash
# Slide 8: reproduce and diagnose the four failure signals from the deck.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

# Pauses so a live presenter can talk through each step (and optionally
# show the Azure Portal alongside this terminal) before the script moves
# on. Automatically skipped, with a note, if stdin isn't a terminal - so
# this never silently hangs an unattended or CI run waiting for a
# keypress nobody can send.
pause() {
  local message="${1:-Press Enter to continue...}"
  if [ -t 0 ]; then
    read -r -p "$message " _
  else
    echo "$message (non-interactive shell detected - continuing automatically)"
  fi
}

cat <<'TXT'
Common failure signals (Slide 8 / Module 1 summary):
  ImagePullBackOff  -> registry path or pull access issue
  CrashLoopBackOff  -> app starts, then exits or fails health checks
  Pending           -> resource requests exceed available node capacity
  No endpoints      -> Service selector does not match Pod labels

Live demo: break the Service selector on purpose, observe "no endpoints",
diagnose, then fix it. This script pauses at each stage - all portal
steps below are optional extras to show alongside it, not required for
the script itself to work.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource ->
     Kubernetes resources -> Services and ingresses ->
     inference-api-external, and note the current selector and its 3
     endpoints. Leave that tab open so you can refresh it later.
  2. AFTER the break (this script also runs this): kubectl get events
     shows nothing new - the Pods never crashed, which is the key
     teaching point: "no endpoints" is a routing problem, not an
     application problem, unlike the other three failure signals.
  3. AFTER the break (Portal): refresh the Services and ingresses page
     and show the endpoint count drop to 0, while the Workloads page
     still shows every Pod Running.
  4. DURING diagnosis (this script also runs this): comparing the
     Service's selector against `kubectl get pods --show-labels` side
     by side is usually enough to spot the mismatch without needing the
     portal at all.
  5. AFTER the fix (Portal or CLI): refresh Services and ingresses to
     watch the endpoint count return to 3, or curl the external IP's
     /health to prove traffic flows again.
TXT
pause "Ready to break it?"

echo "== Break: patch the Service to select a label that doesn't exist =="
kubectl patch svc inference-api-external -n "$NAMESPACE" \
  -p '{"spec":{"selector":{"app":"does-not-exist"}}}'

pause "Selector is now broken - good point to check the Portal (step 1/3 above) before continuing."

echo "== Observe: no endpoints even though Pods are Running =="
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name=inference-api-external
kubectl get pods -n "$NAMESPACE" -l app=inference-api

echo
echo "== Confirm the Pods never actually crashed - this is a routing problem, not an app problem =="
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 5

pause "Compare the empty EndpointSlice against the healthy, unrestarted Pods before diagnosing."

echo "== Diagnose: describe the service, compare selector to Pod labels =="
kubectl describe svc inference-api-external -n "$NAMESPACE"
echo
kubectl get pods -n "$NAMESPACE" --show-labels

pause "The selector mismatch should be visible above. Ready to fix it?"

echo "== Fix: restore the correct selector =="
kubectl patch svc inference-api-external -n "$NAMESPACE" \
  -p '{"spec":{"selector":{"app":"inference-api"}}}'
kubectl get endpointslice -n "$NAMESPACE" -l kubernetes.io/service-name=inference-api-external

echo
echo "Fixed - endpoints should be back. Refresh the Portal Services and ingresses page (step 5 above), or curl the external IP's /health, to confirm."
