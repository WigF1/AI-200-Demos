# Deletes the entire LP05 resource group - the PostgreSQL server and
# everything in it.
$ErrorActionPreference = "Stop"
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp05-postgresql" }

Write-Host "This will delete resource group '$ResourceGroup' and everything in it."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

az group delete --name $ResourceGroup --yes --no-wait
Remove-Item -Path "$PSScriptRoot/.pg-admin-password" -ErrorAction SilentlyContinue
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
