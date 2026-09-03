# Slide 18: app settings, Key Vault reference, deployment slot + slot setting.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1
. ../../../../shared/lib/rbac-wait.ps1

# This module's own script 01 must have run first (webapp must exist) - that's
# expected in-module ordering, not the cross-module dependency this repo is
# fixing. If it's missing, fail with a clear pointer rather than a cryptic
# az error further down.
az webapp show --resource-group $ResourceGroup --name $WebAppName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Web app '$WebAppName' not found. Run ./01-deploy-app-service.ps1 first."
    exit 1
}

az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings APP_ENVIRONMENT=production FEATURE_X_ENABLED=true `
    MODEL_ENDPOINT="https://api.example.com/v1/classify" IMAGE_VERSION=$ImageTag

az keyvault create --resource-group $ResourceGroup --name $KeyVaultName `
  --location $Location --enable-rbac-authorization true --output table
az keyvault secret set --vault-name $KeyVaultName --name $KvSecretName `
  --value "demo-api-key-not-real-1234567890" --output none

$PrincipalId = az webapp identity show --resource-group $ResourceGroup --name $WebAppName --query principalId --output tsv
$KvId = az keyvault show --name $KeyVaultName --query id --output tsv
az role assignment create --assignee $PrincipalId --scope $KvId --role "Key Vault Secrets User"
Wait-ForRoleAssignment -PrincipalId $PrincipalId -Scope $KvId -Role "Key Vault Secrets User"

$SecretUri = az keyvault secret show --vault-name $KeyVaultName --name $KvSecretName --query id --output tsv
$VersionlessUri = $SecretUri.Substring(0, $SecretUri.LastIndexOf('/'))
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings "MODEL_API_KEY=@Microsoft.KeyVault(SecretUri=$VersionlessUri/)"

az webapp deployment slot create --resource-group $ResourceGroup --name $WebAppName `
  --slot $StagingSlotName
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --slot $StagingSlotName --settings APP_ENVIRONMENT=staging --slot-settings APP_ENVIRONMENT

az webapp restart --resource-group $ResourceGroup --name $WebAppName

Write-Host "== Verifying the Key Vault reference resolved (not stuck as an unresolved pointer) =="
$subId = az account show --query id --output tsv
$resolveStatus = "Unknown"
for ($attempt = 1; $attempt -le 8; $attempt++) {
    $url = "https://management.azure.com/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/configreferences/appsettings?api-version=2022-03-01"
    $resolveStatus = az rest --method get --url $url --query "properties.MODEL_API_KEY.status" --output tsv
    if ($resolveStatus -eq "Resolved") {
        Write-Host "MODEL_API_KEY Key Vault reference status: Resolved"
        break
    }
    Write-Host "  attempt $attempt`: status=$resolveStatus - retrying in 10s"
    Start-Sleep -Seconds 10
}
if ($resolveStatus -ne "Resolved") {
    Write-Warning "Reference did not resolve after ~80s (status: $resolveStatus). Usually RBAC propagation - re-run this script."
}

$Host2 = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
Write-Host ""
Write-Host "== /config endpoint (confirms app settings landed in the running container) =="
try {
    (Invoke-WebRequest -Uri "https://$Host2/config" -UseBasicParsing -TimeoutSec 15).Content
} catch {
    Write-Host "  (app may still be restarting - retry manually: curl https://$Host2/config)"
}
