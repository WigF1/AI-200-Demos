# Slide 5: managed, private registry service; Basic/Standard/Premium tiers
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group create --name $ResourceGroup --location $Location --output table
az acr create --resource-group $ResourceGroup --name $AcrName `
  --sku Standard --admin-enabled false --output table
az acr show --name $AcrName --query loginServer --output tsv

Write-ElapsedTime
