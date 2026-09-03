# Slides 16-17: apply ConfigMap + Secret, verify they reach the Pod as env vars.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing
$LoginServer = az acr show --name $AcrName --query loginServer --output tsv

kubectl apply -n $Namespace -f ../manifests/configmap.yaml

Write-Host "== Create the Secret imperatively so no real value is ever committed to git =="
kubectl create secret generic inference-api-secret `
  --from-literal=MODEL_API_KEY='demo-api-key-not-real-1234567890' `
  -n $Namespace --dry-run=client -o yaml | kubectl apply -f -

$deployPath = "$env:TEMP\deployment-configured.yaml"
(Get-Content ../manifests/deployment-configured.yaml) -replace '<ACR_LOGIN_SERVER>', $LoginServer | Set-Content $deployPath
kubectl apply -n $Namespace -f $deployPath
kubectl rollout status deployment/inference-api -n $Namespace

$Pod = kubectl get pods -n $Namespace -l app=inference-api -o jsonpath='{.items[0].metadata.name}'
kubectl exec $Pod -n $Namespace -- python -c "import urllib.request,json; print(json.load(urllib.request.urlopen('http://localhost:8000/config')))"
