# Slide 27, 30: force a CrashLoopBackOff, diagnose via describe + Events, fix.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Break: FORCE_CRASH_DEMO=true makes the container exit on startup =="
kubectl set env deployment/inference-api -n $Namespace FORCE_CRASH_DEMO=true

Start-Sleep -Seconds 20
kubectl get pods -n $Namespace -l app=inference-api

$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
Write-Host "== Diagnose =="
kubectl describe pod $Pod -n $Namespace | Select-Object -Last 30

Write-Host "== Fix =="
kubectl set env deployment/inference-api -n $Namespace FORCE_CRASH_DEMO-
kubectl rollout status deployment/inference-api -n $Namespace
