# Shared variables for LP01/M01 scripts. Edit $Suffix before running.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp01" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp01-container-hosting" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppDir = "../../../../shared/inference-api"
Write-Host "ResourceGroup=$ResourceGroup  Location=$Location  AcrName=$AcrName"
