# Slide 28: EndpointSlices, port-forward before external exposure.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing 2>$null

Write-Host "== Inspect EndpointSlices =="
kubectl get endpointslice -n $Namespace -l kubernetes.io/service-name=inference-api-external

Write-Host "== Port-forward to test internally =="
$job = Start-Job { kubectl port-forward svc/inference-api-internal -n $using:Namespace 8080:80 }
try {
    Start-Sleep -Seconds 3
    try {
        Invoke-RestMethod -Uri http://localhost:8080/health -TimeoutSec 10
    } catch {
        Write-Warning "  (port-forward may not have been ready yet)"
    }
} finally {
    # Always clean up the background job, even if the request above threw -
    # otherwise a failed request leaves the port-forward job orphaned.
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force -ErrorAction SilentlyContinue
}

Write-Host "== External LoadBalancer address =="
kubectl get svc inference-api-external -n $Namespace

Write-ElapsedTime
