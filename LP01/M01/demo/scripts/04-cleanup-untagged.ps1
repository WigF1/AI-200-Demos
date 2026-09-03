# Slide 8: scheduled cleanup of untagged images.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az acr task create --registry $AcrName --name cleanup-untagged `
  --cmd "acr purge --filter '${ImageName}:.*' --untagged --ago 7d" `
  --schedule "0 0 * * 0" --context /dev/null

az acr task run --registry $AcrName --name cleanup-untagged
