# Deletes the entire LP02 resource group - everything all three modules
# created. Prefer the per-module 99-cleanup.ps1 scripts if you only want
# to tear down one module's resources.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp02" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp02-container-apps" }

Write-Host "This will delete resource group '$ResourceGroup' and everything in it."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
