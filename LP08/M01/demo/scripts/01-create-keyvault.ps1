# Slide 6: separate vault, RBAC authorization, grant Secrets Officer.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp08" }
if (-not $Location) { $Location = "eastus" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp08-secrets-config" }
$KeyVaultName = "kv-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az keyvault create `
  --resource-group $ResourceGroup --name $KeyVaultName --location $Location `
  --enable-rbac-authorization true `
  --output table

$UserObjectId = az ad signed-in-user show --query id --output tsv
$KvId = az keyvault show --name $KeyVaultName --query id --output tsv

Write-Host "== Grant yourself Secrets Officer =="
az role assignment create --assignee $UserObjectId --scope $KvId --role "Key Vault Secrets Officer"

Write-Host "== Seed an initial secret version =="
az keyvault secret set --vault-name $KeyVaultName --name "openai-api-key" `
  --value "demo-api-key-v1-not-real" --output table

Write-Host "Vault URL: https://$KeyVaultName.vault.azure.net/"
