#!/usr/bin/env bash
# Slide 27, 30: force a CrashLoopBackOff, diagnose via describe + Events, fix.
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

echo "== Break: point the deployment at a bad env var that crashes readiness (demo /crash route) =="
kubectl set env deployment/inference-api -n "$NAMESPACE" FORCE_CRASH_DEMO="true"

echo "== Observe restart count climbing =="
sleep 20
kubectl get pods -n "$NAMESPACE" -l app=inference-api

POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
echo "== Diagnose: describe the pod and scan Events =="
kubectl describe pod "$POD" -n "$NAMESPACE" | tail -30

echo "== Fix: remove the bad env var =="
kubectl set env deployment/inference-api -n "$NAMESPACE" FORCE_CRASH_DEMO-
kubectl rollout status deployment/inference-api -n "$NAMESPACE"
