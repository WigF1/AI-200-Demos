# Slide 19: live break/fix walkthrough. Previously this was just printed
# instructions in 03-verify-troubleshoot.ps1 - this script actually runs
# them: break WEBSITES_PORT, prove the app fails, fix it, prove it recovers.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

az webapp show --resource-group $ResourceGroup --name $WebAppName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web app '$WebAppName' not found. Run ./01-deploy-app-service.ps1 first."
    exit 1
}

$HostName = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
$HealthUrl = "https://$HostName/health"

function Test-Health {
    param([string]$Label, [bool]$ExpectOk)
    $status = "000"
    for ($attempt = 1; $attempt -le 12; $attempt++) {
        try {
            $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10
            $status = $response.StatusCode
        } catch {
            $status = "000"
        }
        $isOk = ($status -eq 200)
        if ($isOk -eq $ExpectOk) {
            Write-Host "$Label`: HTTP $status (as expected) after $attempt attempt(s)."
            return $true
        }
        Write-Host "  attempt $attempt`: HTTP $status - waiting 10s..."
        Start-Sleep -Seconds 10
    }
    Write-Warning "$Label`: did not reach expected state after 2 minutes (last status: $status)."
    return $false
}

Write-Host "== Baseline: confirm the app is currently healthy =="
Test-Health -Label "Baseline" -ExpectOk $true | Out-Null

Write-Host ""
Write-Host "== Break it: point WEBSITES_PORT at a port the container isn't listening on =="
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=9999 --output none
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Confirm it's actually broken =="
Test-Health -Label "Broken state" -ExpectOk $false | Out-Null

Write-Host ""
Write-Host "== Fix it: restore the correct port =="
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=8000 --output none
az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Confirm it recovered =="
Test-Health -Label "Recovered" -ExpectOk $true | Out-Null
