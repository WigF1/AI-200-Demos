# Slide 26: key signals - latency/errors/restarts, kubectl logs + kubectl top.
Set-Location $PSScriptRoot
. ./00-vars.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

Write-Host "== Pods and restart counts =="
kubectl get pods -n $Namespace -o wide

$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
Write-Host "== Logs for $Pod =="
kubectl logs $Pod -n $Namespace --tail=50

Write-Host "== CPU/memory vs. requests/limits =="
kubectl top pods -n $Namespace
