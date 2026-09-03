# Slide 19: live break/fix walkthrough. Previously this was just printed
# instructions in 03-verify-troubleshoot.ps1 - this script actually runs
# them: break WEBSITES_PORT, prove the app fails, fix it, prove it recovers.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/app-health.ps1

az webapp show --resource-group $ResourceGroup --name $WebAppName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web app '$WebAppName' not found. Run ./01-deploy-app-service.ps1 first."
    exit 1
}

$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
$HealthUrl = "https://$HostName/health"

Write-Host "== Baseline: confirm the app is currently healthy =="
Wait-ForAppHealth -Url $HealthUrl -ExpectHealthy $true | Out-Null

Write-Host ""
Write-Host "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=9999 --output none
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Confirm it's actually broken =="
# App Service serves its own HTTP 200 placeholder page while a container
# is failing to start, so this can take a couple of minutes AND needs the
# body-aware check above - a plain status-code check would report "fine"
# the entire time because the placeholder page is also a 200.
Wait-ForAppHealth -Url $HealthUrl -ExpectHealthy $false -MaxAttempts 18 -DelaySeconds 10 | Out-Null

Write-Host ""
Write-Host "== Fix it: restore the correct port =="
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=8000 --output none
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Confirm it recovered =="
Wait-ForAppHealth -Url $HealthUrl -ExpectHealthy $true | Out-Null
