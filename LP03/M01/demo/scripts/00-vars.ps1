$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp03" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp03-aks" }
$AcrName = "acr$Suffix"
$AksCluster = "aks-$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppDir = "../../../../shared/inference-api"
$Namespace = "ai-workloads"
Write-Host "ResourceGroup=$ResourceGroup  AksCluster=$AksCluster  AcrName=$AcrName"
