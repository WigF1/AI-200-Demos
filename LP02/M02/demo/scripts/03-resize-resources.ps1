# Slide 22: per-replica CPU/memory sizing (memory must be >= 2x CPU).
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/app-health.ps1

Write-Host "== Before: current resources =="
az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query "properties.template.containers[0].resources" --output json

az containerapp update --name $AcaApp --resource-group $ResourceGroup `
  --cpu 0.5 --memory 1.0Gi --output table

Write-Host "== After: confirms the resize actually took effect =="
az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query "properties.template.containers[0].resources" --output json

$Fqdn = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query properties.configuration.ingress.fqdn --output tsv
Write-Host "== Confirm the app is still healthy on the new resource sizing =="
Wait-ForAppHealth -Url "https://$Fqdn/health" -ExpectHealthy $true | Out-Null

Write-ElapsedTime
