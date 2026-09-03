# Deletes the entire LP01 resource group - everything M01 (ACR) and M02
# (App Service, Key Vault, sidecar) created. Use this instead of running
# each module's 99-cleanup.ps1 individually when you're done with the
# whole learning path.
#
# Prefer the per-module 99-cleanup.ps1 scripts if you only want to tear
# down one module's resources and keep working in the other.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp01" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp01-container-hosting" }

Write-Host "This will delete resource group '$ResourceGroup' and everything in it."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
