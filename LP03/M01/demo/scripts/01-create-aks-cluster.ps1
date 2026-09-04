# Slide 5: managed Kubernetes control plane on Azure; attach ACR for pulls.
Set-Location $PSScriptRoot
. ./00-vars.ps1

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
    Write-Host "== Create a small AKS cluster (2 nodes, B2s) for the demo - this takes 5-10 minutes =="
    az aks create `
      --resource-group $ResourceGroup --name $AksCluster `
      --node-count 2 --node-vm-size Standard_B2s `
      --generate-ssh-keys `
      --attach-acr $AcrName `
      --output table
}

az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

Write-Host "== ACR login server to substitute into the manifests =="
az acr show --name $AcrName --query loginServer --output tsv

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
