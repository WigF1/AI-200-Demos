# Slide 18: app settings, Key Vault reference, deployment slot + slot setting.
Set-Location $PSScriptRoot
. ./00-vars.ps1

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

$SecretUri = az keyvault secret show --vault-name $KeyVaultName --name $KvSecretName --query id --output tsv
$VersionlessUri = $SecretUri.Substring(0, $SecretUri.LastIndexOf('/'))
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings "MODEL_API_KEY=@Microsoft.KeyVault(SecretUri=$VersionlessUri/)"

az webapp deployment slot create --resource-group $ResourceGroup --name $WebAppName `
  --slot $StagingSlotName
az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --slot $StagingSlotName --settings APP_ENVIRONMENT=staging --slot-settings APP_ENVIRONMENT

az webapp restart --resource-group $ResourceGroup --name $WebAppName
$Host2 = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
Write-Host "curl https://$Host2/config"
