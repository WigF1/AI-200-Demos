$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp01" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp01-container-hosting" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppServicePlan = "asp-$Suffix"
$WebAppName = "app-$Suffix"
# P0V3 (entry-level Premium v3), not B1 (Basic): 02-configure-app-settings
# creates a staging deployment slot, and Basic tier doesn't support
# deployment slots at all - only Standard, Premium, or Isolated do.
# P0V3 is the cheapest SKU that supports slots and is the current
# Microsoft-recommended default for new deployments (Standard/S1 is the
# older, being-phased-out option at a similar price point). This costs
# meaningfully more than B1 while running - run 99-cleanup.ps1 promptly
# when you're done. See https://azure.microsoft.com/pricing/details/app-service/linux/
$WebAppSku = "P0V3"
$StagingSlotName = "staging"
$KeyVaultName = "kv-$Suffix"
$KvSecretName = "model-api-key"
# Used by 05-sidecar-deploy.ps1 and 99-cleanup.ps1 - kept in one place so
# both always agree on the container name.
$SidecarName = "demo-sidecar"
Write-Host "ResourceGroup=$ResourceGroup  WebAppName=$WebAppName  AcrName=$AcrName"
