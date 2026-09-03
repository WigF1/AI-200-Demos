# Slide 6 & 8: tag vs. digest addressing, image locking.
# Answers Module 1 knowledge check Q2 (pin exact version via digest).
Set-Location $PSScriptRoot
. ./00-vars.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv
$Digest = az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --query digest --output tsv
Write-Host "By tag:    $LoginServer/${ImageName}:${ImageTag}"
Write-Host "By digest: $LoginServer/${ImageName}@$Digest"

az acr repository update --name $AcrName --image "${ImageName}:${ImageTag}" --write-enabled false
az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" `
  --query "{name:name, changeableAttributes:changeableAttributes}" --output json
