# Slide 18: image identity - tags are mutable, digests are immutable.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv

Write-Host "== Rebuild image (simulates a new release) =="
az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir

$Digest = az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --query digest --output tsv
$ImageByDigest = "$LoginServer/${ImageName}@$Digest"
Write-Host "Deploying by digest: $ImageByDigest"

az containerapp update --name $AcaApp --resource-group $ResourceGroup --image $ImageByDigest --output table

az containerapp revision list --name $AcaApp --resource-group $ResourceGroup `
  --query "[].{name:name, active:properties.active, healthState:properties.healthState}" --output table
