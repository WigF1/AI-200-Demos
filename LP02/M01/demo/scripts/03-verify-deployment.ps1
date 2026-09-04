# Slide 10: logs, revisions, replicas.
Set-Location $PSScriptRoot
. ./00-vars.ps1

Write-Host "== Recent console/system logs =="
az containerapp logs show --name $AcaApp --resource-group $ResourceGroup --tail 50

Write-Host "== Revisions =="
az containerapp revision list --name $AcaApp --resource-group $ResourceGroup `
  --query "[].{name:name, active:properties.active, healthState:properties.healthState, trafficWeight:properties.trafficWeight}" `
  --output table

Write-Host "== Replicas for the current revision =="
$LatestRevision = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --revision $LatestRevision --output table

Write-ElapsedTime
