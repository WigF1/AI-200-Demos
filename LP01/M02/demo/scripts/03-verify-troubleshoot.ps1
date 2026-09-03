# Slide 19: logs, Kudu, live break/fix demo (WEBSITES_PORT misconfiguration).
Set-Location $PSScriptRoot
. ./00-vars.ps1

$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv

az webapp log config --resource-group $ResourceGroup --name $WebAppName `
  --docker-container-logging filesystem --output table

Write-Host "Health:   https://$HostName/health"
Write-Host "Config:   https://$HostName/config"
Write-Host "Kudu:     https://$WebAppName.scm.azurewebsites.net"

Write-Host @"

Break/fix demo:
  1) az webapp config appsettings set -g $ResourceGroup -n $WebAppName --settings WEBSITES_PORT=9999
     az webapp restart -g $ResourceGroup -n $WebAppName
  2) Start log tail in another terminal: az webapp log tail -g $ResourceGroup -n $WebAppName
  3) Hit the site again -> observe failure
  4) Fix: az webapp config appsettings set -g $ResourceGroup -n $WebAppName --settings WEBSITES_PORT=8000
     az webapp restart -g $ResourceGroup -n $WebAppName
"@

az webapp log tail --resource-group $ResourceGroup --name $WebAppName
