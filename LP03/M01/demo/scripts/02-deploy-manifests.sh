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
kubectl rollout status deployment/inference-api -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" -l app=inference-api

echo "== 2) Service exposure and endpoint assignment =="
kubectl get svc -n "$NAMESPACE"
kubectl get endpoints inference-api-external -n "$NAMESPACE"

echo "== 3) Logs (only after status/exposure look healthy) =="
POD=$(kubectl get pods -n "$NAMESPACE" -l app=inference-api -o jsonpath='{.items[0].metadata.name}')
kubectl logs "$POD" -n "$NAMESPACE" --tail=50

echo "== External IP (may take a minute to provision) =="
kubectl get svc inference-api-external -n "$NAMESPACE" -w
