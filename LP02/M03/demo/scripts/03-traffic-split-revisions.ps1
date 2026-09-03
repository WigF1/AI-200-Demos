# Slide 34: multiple revision mode + weighted traffic split (canary/blue-green).
Set-Location $PSScriptRoot
. ./00-vars.ps1

az containerapp revision set-mode --name $AcaApp --resource-group $ResourceGroup --mode multiple

az containerapp revision list --name $AcaApp --resource-group $ResourceGroup `
  --query "[].{name:name, active:properties.active}" --output table

$Latest = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
$Previous = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[1].name" --output tsv

Write-Host "== 20/80 canary split: $Latest gets 20%, $Previous gets 80% =="
az containerapp ingress traffic set --name $AcaApp --resource-group $ResourceGroup `
  --revision-weight "${Latest}=20" "${Previous}=80" `
  --output table
