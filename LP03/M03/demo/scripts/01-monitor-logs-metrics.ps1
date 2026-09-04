# Slide 26: key signals - latency/errors/restarts, kubectl logs + kubectl top.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

Write-Host "== Pods and restart counts =="
kubectl get pods -n $Namespace -o wide

$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
Write-Host "== Logs for $Pod =="
kubectl logs $Pod -n $Namespace --tail=50

Write-Host "== CPU/memory vs. requests/limits (needs metrics-server, enabled by default in AKS) =="
kubectl top pods -n $Namespace
if ($LASTEXITCODE -ne 0) { Write-Warning "metrics not ready yet (metrics-server can take a few minutes after cluster creation) - try again shortly" }

Write-ElapsedTime
