$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp01" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp01-container-hosting" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppServicePlan = "asp-$Suffix"
$WebAppName = "app-$Suffix"
$WebAppSku = "B1"
$StagingSlotName = "staging"
$KeyVaultName = "kv-$Suffix"
$KvSecretName = "model-api-key"
Write-Host "ResourceGroup=$ResourceGroup  WebAppName=$WebAppName  AcrName=$AcrName"
