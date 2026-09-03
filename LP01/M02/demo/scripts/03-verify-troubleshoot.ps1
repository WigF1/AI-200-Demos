# Slide 19: logs and Kudu diagnostic surfaces.
# The break/fix demo (WEBSITES_PORT misconfiguration) is its own script,
# 04-break-fix-demo.ps1, so it can be re-run independently and actually
# executes the steps instead of just printing them.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

az webapp show --resource-group $ResourceGroup --name $WebAppName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web app '$WebAppName' not found. Run ./01-deploy-app-service.ps1 first."
    exit 1
}

$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv

az webapp log config --resource-group $ResourceGroup --name $WebAppName `
  --docker-container-logging filesystem --output table

Write-Host "Health:   https://$HostName/health"
Write-Host "Config:   https://$HostName/config"
Write-Host "Kudu:     https://$WebAppName.scm.azurewebsites.net"
Write-Host ""
Write-Host "For a live break/fix walkthrough (bad WEBSITES_PORT -> observe failure -> fix), run ./04-break-fix-demo.ps1"
Write-Host "Tailing logs now (Ctrl+C to stop) ..."

az webapp log tail --resource-group $ResourceGroup --name $WebAppName
