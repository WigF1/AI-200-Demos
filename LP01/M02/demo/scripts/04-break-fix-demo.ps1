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

Write-Host "NOTE: this uses 'az webapp stop' + 'az webapp start' rather than 'az webapp restart'."
Write-Host "Testing showed 'restart' doesn't reliably tear down the container that's already"
Write-Host "serving traffic - a new (broken) container can fail behind the scenes while Azure"
Write-Host "keeps the old one alive and answering requests, making the app LOOK unaffected."
Write-Host "A full stop guarantees nothing is left running before the bad config is applied."
Write-Host "Also avoid running other scripts against this app (e.g. 03-verify-troubleshoot.ps1)"
Write-Host "while this is running - any config change triggers its own restart, which can still"
Write-Host "race this one."
Write-Host ""

$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
$HealthUrl = "https://$HostName/health"

Write-Host "== Baseline: confirm the app is currently healthy =="
Wait-ForAppHealth -Url $HealthUrl -ExpectHealthy $true | Out-Null

Write-Host ""
Write-Host "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=9999 --output none
az webapp stop --resource-group $ResourceGroup --name $WebAppName
az webapp start --resource-group $ResourceGroup --name $WebAppName

# Self-check: confirm the setting actually stuck before trusting the health
# poll below. If something else (another script, a concurrent restart)
# raced this and the live value isn't 9999, the "still healthy" result
# that follows would otherwise look like a mystery instead of explaining
# itself.
$LivePort = az webapp config appsettings list --resource-group $ResourceGroup --name $WebAppName `
  --query "[?name=='WEBSITES_PORT'].value | [0]" --output tsv
if ($LivePort -ne "9999") {
    Write-Warning "WEBSITES_PORT currently reads '$LivePort', not 9999 - something else changed it"
    Write-Warning "(likely a concurrent restart from another script). The 'confirm broken' check"
    Write-Warning "below is not trustworthy this run - stop, make sure no other script is touching"
    Write-Warning "this app, and re-run."
}

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
az webapp stop --resource-group $ResourceGroup --name $WebAppName
az webapp start --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Confirm it recovered =="
Wait-ForAppHealth -Url $HealthUrl -ExpectHealthy $true | Out-Null
