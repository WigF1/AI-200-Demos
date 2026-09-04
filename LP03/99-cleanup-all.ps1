# Deletes the entire LP03 resource group - the AKS cluster, ACR, and
# everything all three modules deployed into the cluster.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp03" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp03-aks" }

Write-Host "This will delete resource group '$ResourceGroup' and everything in it (including the AKS cluster)."
$confirm = Read-Host "Type the resource group name to confirm"
if ($confirm -ne $ResourceGroup) {
    Write-Error "Confirmation did not match. Aborting."
    exit 1
}

az group delete --name $ResourceGroup --yes --no-wait
Write-Host "Deletion started (--no-wait). Track progress with: az group show --name $ResourceGroup"
