# Slide 8: reproduce and diagnose the four failure signals from the deck.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host @"
Common failure signals (Slide 8 / Module 1 summary):
  ImagePullBackOff  -> registry path or pull access issue
  CrashLoopBackOff  -> app starts, then exits or fails health checks
  Pending           -> resource requests exceed available node capacity
  No endpoints      -> Service selector does not match Pod labels
"@

Write-Host "== Break: patch the Service to select a label that doesn't exist =="
kubectl patch svc inference-api-external -n $Namespace -p '{\"spec\":{\"selector\":{\"app\":\"does-not-exist\"}}}'

Write-Host "== Observe: no endpoints even though Pods are Running =="
kubectl get endpoints inference-api-external -n $Namespace
kubectl get pods -n $Namespace -l app=inference-api

Write-Host "== Diagnose =="
kubectl describe svc inference-api-external -n $Namespace

Write-Host "== Fix =="
kubectl patch svc inference-api-external -n $Namespace -p '{\"spec\":{\"selector\":{\"app\":\"inference-api\"}}}'
kubectl get endpoints inference-api-external -n $Namespace

Write-ElapsedTime
