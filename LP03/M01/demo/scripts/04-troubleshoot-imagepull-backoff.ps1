# Slide 8: reproduce and diagnose ImagePullBackOff (registry path or pull
# access issue). Same pause/portal-guidance pattern as
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

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv

Write-Host @"
ImagePullBackOff: the node can't pull the container image - wrong tag,
wrong repository, or missing pull access are the usual causes.

Suggested order to run/show alongside this script:
  1. BEFORE breaking anything (Portal): open the AKS resource ->
     Kubernetes resources -> Workloads -> inference-api, and note all 3
     Pods are Running with the current image tag.
  2. AFTER the break (Portal): refresh Workloads and watch the Pod
     status column cycle through ErrImagePull -> ImagePullBackOff.
  3. DURING diagnosis (this script also runs this): kubectl describe pod
     shows the exact pull failure in Events - e.g. "manifest for
     ...:does-not-exist not found" - which tells you immediately whether
     it's a bad tag, a bad repo name, or an auth problem, without
     needing to guess.
  4. AFTER the fix (Portal or CLI): refresh Workloads / kubectl get pods
     to confirm all 3 Pods return to Running with the correct image.
"@
Wait-ForPresenter "Ready to break it?"

Write-Host "== Break: point the deployment at a tag that doesn't exist =="
kubectl set image deployment/inference-api inference-api="$LoginServer/inference-api:does-not-exist" -n $Namespace

Wait-ForPresenter "Image reference is now broken - good point to check the Portal Workloads page before continuing."

Write-Host "== Observe: Pod status cycling through ErrImagePull / ImagePullBackOff (waits up to 60s) =="
for ($attempt = 1; $attempt -le 6; $attempt++) {
    kubectl get pods -n $Namespace -l app=inference-api
    $statusMatch = kubectl get pods -n $Namespace -l app=inference-api `
      -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>$null
    if ($statusMatch -match "ImagePullBackOff|ErrImagePull") { break }
    Start-Sleep -Seconds 10
}

Wait-ForPresenter "Pods should show ImagePullBackOff/ErrImagePull above. Ready to diagnose?"

Write-Host "== Diagnose: describe a Pod and read the exact pull error in Events =="
$pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl describe pod $pod -n $Namespace | Select-Object -Last 20

Wait-ForPresenter "The exact pull failure reason should be visible above. Ready to fix it?"

Write-Host "== Fix: restore the correct image tag =="
kubectl set image deployment/inference-api inference-api="$LoginServer/inference-api:v1" -n $Namespace
kubectl rollout status deployment/inference-api -n $Namespace --timeout=120s

Write-Host ""
Write-Host "Fixed - all 3 Pods should be Running again. Refresh the Portal Workloads page (step 4 above) to confirm."

Write-ElapsedTime
