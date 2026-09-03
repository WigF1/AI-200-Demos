# Slide 15-17: custom Linux container from ACR, managed identity + AcrPull, WEBSITES_PORT, health check.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/rbac-wait.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv
$ImageRef = "$LoginServer/${ImageName}:${ImageTag}"

az appservice plan create --resource-group $ResourceGroup --name $AppServicePlan `
  --is-linux --sku $WebAppSku --output table

# You'll see a warning here: "No credential was provided to access Azure
# Container Registry... Retrieving credentials failed..." That's expected,
# not a failure - 00-ensure-prereqs.ps1 (mirroring 01-create-acr.ps1)
# deliberately creates the ACR with --admin-enabled false, so there ARE no
# admin credentials for az to fall back to. The app is created pointing at
# the image regardless; it just can't pull it yet. The role assignment +
# acrUseManagedIdentityCreds below are what actually let it pull, which is
# the whole point of this module (managed identity over admin credentials,
# slide 16).
az webapp create --resource-group $ResourceGroup --plan $AppServicePlan `
  --name $WebAppName --container-image-name $ImageRef --output table

az webapp identity assign --resource-group $ResourceGroup --name $WebAppName --output table
$PrincipalId = az webapp identity show --resource-group $ResourceGroup --name $WebAppName --query principalId --output tsv
$AcrId = az acr show --name $AcrName --query id --output tsv

az role assignment create --assignee $PrincipalId --scope $AcrId --role "AcrPull"
Wait-ForRoleAssignment -PrincipalId $PrincipalId -Scope $AcrId -Role "AcrPull"

az webapp config set --resource-group $ResourceGroup --name $WebAppName `
  --generic-configurations '{\"acrUseManagedIdentityCreds\": true}'

az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=8000

az webapp config set --resource-group $ResourceGroup --name $WebAppName --always-on true
az webapp config set --resource-group $ResourceGroup --name $WebAppName `
  --generic-configurations '{\"healthCheckPath\": \"/health\"}'

az webapp restart --resource-group $ResourceGroup --name $WebAppName

$Host2 = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
$HealthUrl = "https://$Host2/health"
Write-Host "== Verifying the app comes up healthy: $HealthUrl =="
$status = "000"
for ($attempt = 1; $attempt -le 12; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri $HealthUrl -UseBasicParsing -TimeoutSec 10
        $status = $response.StatusCode
    } catch {
        $status = "000"
    }
    if ($status -eq 200) {
        Write-Host "Healthy (HTTP $status) after $attempt attempt(s)."
        break
    }
    Write-Host "  attempt $attempt`: HTTP $status - retrying in 10s (cold start / image pull can take a minute)"
    Start-Sleep -Seconds 10
}
if ($status -ne 200) {
    Write-Warning "Still not healthy after 2 minutes - check logs: az webapp log tail -g $ResourceGroup -n $WebAppName"
}
