$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp02" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp02-container-apps" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppDir = "../../../../shared/inference-api"
$AcaEnv = "env-$Suffix"
$AcaApp = "aca-$Suffix"
$LogAnalyticsWorkspace = "law-$Suffix"
Write-Host "ResourceGroup=$ResourceGroup  AcaEnv=$AcaEnv  AcaApp=$AcaApp"
