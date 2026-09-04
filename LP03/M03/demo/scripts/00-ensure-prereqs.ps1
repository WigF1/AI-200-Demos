# Makes this module runnable without LP03/M01 having run first. Mirrors
# M01's cluster/ACR creation and base deployment, each step checking
# existence first so this is a fast no-op when M01 already ran. AKS
# cluster creation takes 5-10 minutes if starting cold.

Write-Host "== Ensuring prerequisites for LP03/M03 (ACR, image, AKS cluster, base deployment) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az acr show --name $AcrName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ACR '$AcrName' already exists."
} else {
    az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard --admin-enabled false --output table
}

az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir
}

az aks show --resource-group $ResourceGroup --name $AksCluster --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "AKS cluster '$AksCluster' already exists."
} else {
    Write-Host "AKS cluster '$AksCluster' not found - creating (this takes 5-10 minutes)..."
    Invoke-TimedStep "AKS cluster create" {
        az aks create `
          --resource-group $ResourceGroup --name $AksCluster `
          --node-count 2 --node-vm-size Standard_B2s `
          --generate-ssh-keys `
          --attach-acr $AcrName `
          --output table
    }
}

az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

kubectl get deployment inference-api -n $Namespace --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Base deployment not found - applying it from LP03/M01's manifests..."
    $LoginServer = az acr show --name $AcrName --query loginServer --output tsv
    $deploymentPath = "$env:TEMP\deployment.yaml"
    (Get-Content ../../../M01/demo/manifests/deployment.yaml) -replace '<ACR_LOGIN_SERVER>', $LoginServer | Set-Content $deploymentPath
    kubectl apply -n $Namespace -f $deploymentPath
    kubectl apply -n $Namespace -f ../../../M01/demo/manifests/service-loadbalancer.yaml
    kubectl apply -n $Namespace -f ../../../M01/demo/manifests/service-clusterip.yaml
    kubectl rollout status deployment/inference-api -n $Namespace --timeout=120s
}

Write-Host "Prerequisites ready."
