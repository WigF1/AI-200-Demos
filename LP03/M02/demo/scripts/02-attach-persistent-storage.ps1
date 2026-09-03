# Slide 18: PVC bound status, then prove data survives a Pod restart.
Set-Location $PSScriptRoot
. ./00-vars.ps1

kubectl apply -n $Namespace -f ../manifests/pvc.yaml

Write-Host "== Confirm PVC status is Bound =="
Start-Sleep -Seconds 15
kubectl get pvc inference-api-data -n $Namespace

Write-Host "== Write a test file, delete the Pod, verify the file persists =="
$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl exec $Pod -n $Namespace -- sh -c "echo 'hello from before restart' > /data/test.txt"
kubectl delete pod $Pod -n $Namespace
kubectl rollout status deployment/inference-api -n $Namespace

$NewPod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
Write-Host "New pod: $NewPod -- reading the same file back:"
kubectl exec $NewPod -n $Namespace -- cat /data/test.txt
