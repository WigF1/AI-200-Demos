$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp03" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp03-aks" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppDir = "../../../../shared/inference-api"
$AksCluster = "aks-$Suffix"
$Namespace = "ai-workloads"
Write-Host "ResourceGroup=$ResourceGroup  AksCluster=$AksCluster  Namespace=$Namespace"
