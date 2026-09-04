# Slides 16-17: apply ConfigMap + Secret, verify they reach the Pod as env vars.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing
$LoginServer = az acr show --name $AcrName --query loginServer --output tsv

kubectl apply -n $Namespace -f ../manifests/configmap.yaml

Write-Host "== Create the Secret imperatively so no real value is ever committed to git =="
kubectl create secret generic inference-api-secret `
  --from-literal=MODEL_API_KEY='demo-api-key-not-real-1234567890' `
  -n $Namespace --dry-run=client -o yaml | kubectl apply -f -

# deployment-configured.yaml mounts a PVC (inference-api-data) - apply it
# here too, even though 02-attach-persistent-storage.ps1 is the module
# that properly covers PVCs, so the deployment below doesn't reference a
# volume that doesn't exist yet and leave its pods stuck Pending. Applying
# it twice (once here, once in 02) is harmless - kubectl apply is idempotent.
kubectl apply -n $Namespace -f ../manifests/pvc.yaml

$deployPath = "$env:TEMP\deployment-configured.yaml"
(Get-Content ../manifests/deployment-configured.yaml) -replace '<ACR_LOGIN_SERVER>', $LoginServer | Set-Content $deployPath
kubectl apply -n $Namespace -f $deployPath
kubectl rollout status deployment/inference-api -n $Namespace --timeout=120s

$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl exec $Pod -n $Namespace -- python -c "import urllib.request,json; print(json.load(urllib.request.urlopen('http://localhost:8000/config')))"

Write-ElapsedTime
