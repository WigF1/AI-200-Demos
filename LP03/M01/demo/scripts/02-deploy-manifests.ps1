# Slide 8: apply manifests, verification order (Pod status -> Service exposure -> logs).
Set-Location $PSScriptRoot
. ./00-vars.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv

$deploymentPath = "$env:TEMP\deployment.yaml"
(Get-Content ../manifests/deployment.yaml) -replace '<ACR_LOGIN_SERVER>', $LoginServer | Set-Content $deploymentPath

kubectl apply -n $Namespace -f $deploymentPath
kubectl apply -n $Namespace -f ../manifests/service-loadbalancer.yaml
kubectl apply -n $Namespace -f ../manifests/service-clusterip.yaml

Write-Host "== 1) Pod and Deployment status =="
kubectl rollout status deployment/inference-api -n $Namespace
kubectl get pods -n $Namespace -l app=inference-api

Write-Host "== 2) Service exposure and endpoint assignment =="
kubectl get svc -n $Namespace
kubectl get endpoints inference-api-external -n $Namespace

Write-Host "== 3) Logs =="
$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl logs $Pod -n $Namespace --tail=50

Write-Host "== External IP (may take a minute) =="
kubectl get svc inference-api-external -n $Namespace -w
