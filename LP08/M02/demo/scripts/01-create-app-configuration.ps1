# Slide 17: store, RBAC, labeled key-values, feature flag, Key Vault reference.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp08" }
if (-not $Location) { $Location = "eastus" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp08-secrets-config" }
$AppConfigName = "appcs-$Suffix"
$KeyVaultName = "kv-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az appconfig create `
  --resource-group $ResourceGroup --name $AppConfigName --location $Location `
  --sku Free `
  --output table

$UserObjectId = az ad signed-in-user show --query id --output tsv
$AppConfigId = az appconfig show --resource-group $ResourceGroup --name $AppConfigName --query id --output tsv
az role assignment create --assignee $UserObjectId --scope $AppConfigId --role "App Configuration Data Owner"

Write-Host "== Labeled key-values =="
az appconfig kv set --name $AppConfigName --key "Pipeline:BatchSize" --value "10" --label "Production" --yes
az appconfig kv set --name $AppConfigName --key "Pipeline:BatchSize" --value "2" --label "Development" --yes

Write-Host "== Feature flag =="
az appconfig feature set --name $AppConfigName --feature "UseNewModel" --yes

Write-Host "== Key Vault reference - requires kv-$Suffix from LP08/M01 =="
$kvExists = az keyvault show --name $KeyVaultName 2>$null
if ($kvExists) {
  $SecretId = az keyvault secret show --vault-name $KeyVaultName --name openai-api-key --query id --output tsv
  az appconfig kv set-keyvault --name $AppConfigName --key "OpenAI:ApiKey" --secret-identifier $SecretId --yes
  Write-Host "Grant the app's managed identity 'App Configuration Data Reader' on this store AND 'Key Vault Secrets User' on $KeyVaultName"
} else {
  Write-Host "(kv-$Suffix not found - run LP08/M01's 01-create-keyvault first for the reference demo)"
}

Write-Host "App Configuration endpoint:"
az appconfig show --resource-group $ResourceGroup --name $AppConfigName --query endpoint --output tsv
