# Deletes the entire LP07 resource group - Service Bus, Event Grid, and
# the Function App/storage account, all in one place.
$ErrorActionPreference = "Stop"
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }

Write-Host "This will delete resource group '$ResourceGroup' and everything in it."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
