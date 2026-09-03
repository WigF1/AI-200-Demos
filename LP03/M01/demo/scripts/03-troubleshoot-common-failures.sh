#!/usr/bin/env bash
# Slide 8: reproduce and diagnose the four failure signals from the deck.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

cat <<'TXT'
Common failure signals (Slide 8 / Module 1 summary):
  ImagePullBackOff  -> registry path or pull access issue
  CrashLoopBackOff  -> app starts, then exits or fails health checks
  Pending           -> resource requests exceed available node capacity
  No endpoints      -> Service selector does not match Pod labels

Live demo: break the selector on purpose, observe "no endpoints", then fix it.
TXT

echo "== Break: patch the Service to select a label that doesn't exist =="
kubectl patch svc inference-api-external -n "$NAMESPACE" \
  -p '{"spec":{"selector":{"app":"does-not-exist"}}}'

echo "== Observe: no endpoints even though Pods are Running =="
kubectl get endpoints inference-api-external -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l app=inference-api

echo "== Diagnose: describe the service, compare selector to Pod labels =="
kubectl describe svc inference-api-external -n "$NAMESPACE"

echo "== Fix: restore the correct selector =="
kubectl patch svc inference-api-external -n "$NAMESPACE" \
  -p '{"spec":{"selector":{"app":"inference-api"}}}'
kubectl get endpoints inference-api-external -n "$NAMESPACE"
