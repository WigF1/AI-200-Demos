# Slide 8: reproduce and diagnose CrashLoopBackOff (app starts, then
# exits or fails health checks). Same pause/portal-guidance pattern as
# 03-troubleshoot-common-failures.ps1. Uses the same FORCE_CRASH_DEMO
# mechanism as LP03/M03/02-break-and-diagnose.ps1 (that script covers
# the Module 3 monitoring angle on the same failure; this one is the
# Module 1 "recognize the four signals" angle).
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing 2>$null

function Wait-ForPresenter {
    param([string]$Message = "Press Enter to continue...")
    if ([Console]::IsInputRedirected) {
        Write-Host "$Message (non-interactive shell detected - continuing automatically)"
    } else {
        Read-Host $Message | Out-Null
    }
}

Write-Host @"
CrashLoopBackOff: the container starts, then exits (or fails its
liveness probe) repeatedly - the platform backs off between restarts.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource ->
     Kubernetes resources -> Workloads -> inference-api, and note the
     Restarts column reads 0 for all 3 Pods.
  2. AFTER the break (Portal): refresh Workloads and watch Restarts
     climb and the status cycle Running -> CrashLoopBackOff.
  3. DURING diagnosis (this script also runs this): kubectl logs
     --previous reads the crashed container's own output directly -
     usually faster than describe/Events for an application-level
     crash, since the app's own error message is right there.
  4. AFTER the fix (Portal or CLI): refresh Workloads to confirm Restarts
     stop climbing and every Pod is back to Running.
"@
Wait-ForPresenter "Ready to break it?"

Write-Host "== Break: set FORCE_CRASH_DEMO=true so the container exits on startup =="
kubectl set env deployment/inference-api -n $Namespace FORCE_CRASH_DEMO=true

Wait-ForPresenter "Crash flag is now set - good point to check the Portal Workloads page before continuing."

Write-Host "== Observe: restart count climbing, status cycling toward CrashLoopBackOff (waits up to 60s) =="
for ($attempt = 1; $attempt -le 6; $attempt++) {
    kubectl get pods -n $Namespace -l app=inference-api
    $statusMatch = kubectl get pods -n $Namespace -l app=inference-api `
      -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>$null
    if ($statusMatch -match "CrashLoopBackOff") { break }
    Start-Sleep -Seconds 10
}

Wait-ForPresenter "Pods should show climbing restarts / CrashLoopBackOff above. Ready to diagnose?"

Write-Host "== Diagnose: read the crashed container's own logs (faster than Events for an app-level crash) =="
$pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl logs $pod -n $Namespace --previous --tail=20
if ($LASTEXITCODE -ne 0) { Write-Host "  (no previous container yet - it may still be on its first crash; re-run this line in a few seconds)" }
Write-Host ""
Write-Host "== Events, for comparison =="
kubectl describe pod $pod -n $Namespace | Select-Object -Last 15

Wait-ForPresenter "The app's own crash message should be visible above. Ready to fix it?"

Write-Host "== Fix: remove the crash flag =="
kubectl set env deployment/inference-api -n $Namespace FORCE_CRASH_DEMO-
kubectl rollout status deployment/inference-api -n $Namespace --timeout=120s

Write-Host ""
Write-Host "Fixed - restarts should stop climbing and all 3 Pods return to Running. Refresh the Portal Workloads page (step 4 above) to confirm."

Write-ElapsedTime
