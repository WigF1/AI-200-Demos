# Slide 22: per-replica CPU/memory sizing (memory must be >= 2x CPU).
Set-Location $PSScriptRoot
. ./00-vars.ps1

az containerapp update --name $AcaApp --resource-group $ResourceGroup --cpu 0.5 --memory 1.0Gi --output table
az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query "properties.template.containers[0].resources" --output json
