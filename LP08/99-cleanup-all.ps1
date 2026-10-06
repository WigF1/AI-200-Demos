# Deletes the entire LP08 resource group - Key Vault and App Configuration,
# all in one place.
#
# The vault is deleted and PURGED first: Key Vault soft-delete keeps a
# deleted vault (and its name - names are global) for 90 days, so without
# the purge, LP08/M01's 01-create-keyvault fails on the next run with a
# name conflict. App Configuration is created on the Free tier, which has
# no soft-delete, so the resource group delete is enough for it.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp08" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp08-secrets-config" }
$KeyVaultName = "kv-$Suffix"

Write-Host "This will delete resource group '$ResourceGroup' and everything in it,"
Write-Host "and permanently purge Key Vault '$KeyVaultName' (no soft-delete recovery)."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

Write-Host "== Deleting and purging Key Vault '$KeyVaultName' =="
az keyvault show --name $KeyVaultName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    az keyvault delete --name $KeyVaultName --output none
}
# Also catches a vault already soft-deleted by an earlier group delete.
az keyvault show-deleted --name $KeyVaultName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    az keyvault purge --name $KeyVaultName --location $Location --output none
    Write-Host "  Purged."
} else {
    Write-Host "  (no Key Vault found)"
}

az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
