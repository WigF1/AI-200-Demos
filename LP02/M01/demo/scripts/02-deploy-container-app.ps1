# Slide 7-9: containerapp create, managed identity + AcrPull, env vars/secrets.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ../../../../shared/lib/rbac-wait.ps1
. ../../../../shared/lib/app-health.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv
$ImageRef = "$LoginServer/${ImageName}:${ImageTag}"

az containerapp show --name $AcaApp --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Container app '$AcaApp' already exists - updating image/env instead of creating."
    az containerapp update --name $AcaApp --resource-group $ResourceGroup `
      --image $ImageRef `
      --set-env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" "MODEL_API_KEY=secretref:model-api-key" `
      --output table
} else {
    Write-Host "== Create the container app with a system-assigned identity and a secret =="
    # --registry-identity system needs the identity to already exist to pull
    # successfully at creation time - it doesn't yet (chicken/egg), so the
    # first pull attempt during create is expected to fail/retry. The role
    # assignment + explicit restart below is what actually gets it running.
    az containerapp create `
      --name $AcaApp --resource-group $ResourceGroup --environment $AcaEnv `
      --image $ImageRef `
      --target-port 8000 --ingress external `
      --registry-server $LoginServer --registry-identity system `
      --system-assigned `
      --secrets "model-api-key=demo-api-key-not-real-1234567890" `
      --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" `
                 "MODEL_API_KEY=secretref:model-api-key" `
      --min-replicas 1 --max-replicas 3 `
      --output table
}

$PrincipalId = az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query identity.principalId --output tsv
$AcrId = az acr show --name $AcrName --query id --output tsv
Set-RoleAssignment -PrincipalId $PrincipalId -Scope $AcrId -Role "AcrPull"

Write-Host "== Restart so the app retries the image pull now that AcrPull is granted =="
$LatestRevision = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
az containerapp revision restart --name $AcaApp --resource-group $ResourceGroup --revision $LatestRevision --output none

$Fqdn = az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query properties.configuration.ingress.fqdn --output tsv
Write-Host "== App URL: https://$Fqdn =="

Write-Host "== Verifying the app comes up healthy =="
if (-not (Wait-ForAppHealth -Url "https://$Fqdn/health" -ExpectHealthy $true)) {
    Write-Warning "Still not healthy - check: az containerapp logs show -n $AcaApp -g $ResourceGroup --follow"
}
