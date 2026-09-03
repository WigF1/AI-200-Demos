# Slide 7: ACR Tasks quick build - cloud build, no local Docker needed.
# Answers Module 1 knowledge check Q1 (inconsistent local builds).
Set-Location $PSScriptRoot
. ./00-vars.ps1

az acr build --registry $AcrName `
  --image "${ImageName}:${ImageTag}" --image "${ImageName}:latest" `
  --file "$AppDir/Dockerfile" $AppDir

az acr repository show-tags --name $AcrName --repository $ImageName --output table
