# Slide 5: managed Kubernetes control plane on Azure; attach ACR for pulls.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group create --name $ResourceGroup --location $Location --output table

az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard --admin-enabled false --output table
az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir

Write-Host "== Create a small AKS cluster (2 nodes, B2s) for the demo =="
az aks create `
  --resource-group $ResourceGroup --name $AksCluster `
  --node-count 2 --node-vm-size Standard_B2s `
  --generate-ssh-keys `
  --attach-acr $AcrName `
  --output table

az aks get-credentials --resource-group $ResourceGroup --name $AksCluster --overwrite-existing

az acr show --name $AcrName --query loginServer --output tsv

kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -
