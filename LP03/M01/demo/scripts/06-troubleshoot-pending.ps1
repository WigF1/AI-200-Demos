# Slide 8: reproduce and diagnose Pending (resource requests exceed
# available node capacity). Same pause/portal-guidance pattern as
# 03-troubleshoot-common-failures.ps1.
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

# These match deployment.yaml exactly, so "fix" restores the real
# original values rather than an approximation.
$OriginalCpuRequest = "100m"
$OriginalMemRequest = "128Mi"

Write-Host @"
Pending: the scheduler can't find a node with enough free CPU/memory to
satisfy the Pod's resource requests, so it never gets placed at all.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource -> Node
     pools (or Kubernetes resources -> Nodes), and note how much
     allocatable CPU/memory each node reports.
  2. AFTER the break (Portal): refresh Kubernetes resources -> Workloads
     and watch a new Pod sit in Pending indefinitely - unlike the other
     three failure signals, it never even reaches "Running" once to
     then fail; it's stuck before scheduling.
  3. DURING diagnosis (this script also runs this): kubectl describe pod
     shows a FailedScheduling event with the exact shortfall (e.g.
     "0/2 nodes are available: 2 Insufficient cpu") - the cleanest
     evidence this is a capacity problem, not an app problem.
  4. AFTER the fix (Portal or CLI): refresh Workloads to confirm the
     Pod moves from Pending to Running once requests are realistic again.
"@
Wait-ForPresenter "Ready to break it?"

Write-Host "== Break: request 100 CPU cores per replica (no node in this cluster has that much) =="
kubectl set resources deployment/inference-api -n $Namespace --containers=inference-api --requests=cpu=100

Wait-ForPresenter "Resource request is now unsatisfiable - good point to check the Portal Node pools page before continuing."

Write-Host "== Observe: new Pod(s) stuck Pending (waits up to 60s) =="
for ($attempt = 1; $attempt -le 6; $attempt++) {
    kubectl get pods -n $Namespace -l app=inference-api
    $pendingCount = (kubectl get pods -n $Namespace -l app=inference-api --field-selector=status.phase=Pending -o name | Measure-Object).Count
    if ($pendingCount -gt 0) { break }
    Start-Sleep -Seconds 10
}

Wait-ForPresenter "At least one Pod should show Pending above. Ready to diagnose?"

Write-Host "== Diagnose: describe the Pending Pod and read the FailedScheduling event =="
$pendingPod = kubectl get pods -n $Namespace -l app=inference-api --field-selector=status.phase=Pending -o jsonpath='{.items[0].metadata.name}'
if ($pendingPod) {
    kubectl describe pod $pendingPod -n $Namespace | Select-Object -Last 15
} else {
    Write-Host "  (no Pending Pod found by name - list above should still show the phase)"
}

Wait-ForPresenter "The exact capacity shortfall should be visible above. Ready to fix it?"

Write-Host "== Fix: restore the real resource requests from deployment.yaml =="
kubectl set resources deployment/inference-api -n $Namespace --containers=inference-api `
  --requests="cpu=$OriginalCpuRequest,memory=$OriginalMemRequest"
kubectl rollout status deployment/inference-api -n $Namespace --timeout=120s

Write-Host ""
Write-Host "Fixed - the Pending Pod should now schedule and run. Refresh the Portal Workloads page (step 4 above) to confirm."

Write-ElapsedTime
