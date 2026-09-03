# Slide 28: EndpointSlices, port-forward before external exposure.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Inspect EndpointSlices =="
kubectl get endpointslice -n $Namespace -l kubernetes.io/service-name=inference-api-external

Write-Host "== Port-forward to test internally =="
$job = Start-Job { kubectl port-forward svc/inference-api-internal -n $using:Namespace 8080:80 }
Start-Sleep -Seconds 3
Invoke-RestMethod http://localhost:8080/health
Stop-Job $job; Remove-Job $job

Write-Host "== External LoadBalancer address =="
kubectl get svc inference-api-external -n $Namespace
