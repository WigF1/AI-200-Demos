# Slide 19, 21: lifecycle actions (stop/restart/deactivate) and readiness/liveness probes.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az containerapp update --name $AcaApp --resource-group $ResourceGroup --set-env-vars "PROBE_DEMO=true" --output table

$yamlPath = "$env:TEMP\aca-app.yaml"
az containerapp show --name $AcaApp --resource-group $ResourceGroup --output yaml | Out-File -FilePath $yamlPath
Write-Host "Exported current config to $yamlPath - add a probes: block, then:"
Write-Host "  az containerapp update -n $AcaApp -g $ResourceGroup --yaml `"$yamlPath`""

$LatestRevision = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
Write-Host "Deactivate one revision (isolates a bad release):"
Write-Host "  az containerapp revision deactivate --revision $LatestRevision -g $ResourceGroup"
Write-Host "Restart the whole app (clears transient state):"
Write-Host "  az containerapp restart -n $AcaApp -g $ResourceGroup"
