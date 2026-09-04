#!/usr/bin/env bash
# Slide 8: apply manifests, verification order (Pod status -> Service exposure -> logs).
set -euo pipefail
cd "$(dirname "$0")"; source ./00-vars.sh

LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer --output tsv)

echo "== Substitute the ACR login server into the manifests =="
sed "s#<ACR_LOGIN_SERVER>#${LOGIN_SERVER}#g" ../manifests/deployment.yaml > /tmp/deployment.yaml

kubectl apply -n "$NAMESPACE" -f /tmp/deployment.yaml
kubectl apply -n "$NAMESPACE" -f ../manifests/service-loadbalancer.yaml
kubectl apply -n "$NAMESPACE" -f ../manifests/service-clusterip.yaml

echo "== 1) Pod and Deployment status =="
kubectl rollout status deployment/inference-api -n "$NAMESPACE" --timeout=120s || echo "  rollout did not complete within 120s - check: kubectl get pods -n $NAMESPACE" >&2
kubectl get pods -n "$NAMESPACE" -l app=inference-api

echo "== 2) Service exposure and endpoint assignment =="
kubectl get svc -n "$NAMESPACE"
kubectl get endpoints inference-api-external -n "$NAMESPACE"

echo "== 3) Logs (only after status/exposure look healthy) =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n "$NAMESPACE" --tail=50

echo "== External IP (waits up to 2 minutes for provisioning) =="
for attempt in $(seq 1 12); do
  EXTERNAL_IP=$(kubectl get svc inference-api-external -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$EXTERNAL_IP" ]; then
    echo "External IP assigned: $EXTERNAL_IP"
    break
  fi
  echo "  attempt ${attempt}: not yet assigned - retrying in 10s"
  sleep 10
done
kubectl get svc inference-api-external -n "$NAMESPACE"
