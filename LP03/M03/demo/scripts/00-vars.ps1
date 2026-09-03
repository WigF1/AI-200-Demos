$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp03" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp03-aks" }
$AksCluster = "aks-$Suffix"
$Namespace = "ai-workloads"
Write-Host "ResourceGroup=$ResourceGroup  AksCluster=$AksCluster  Namespace=$Namespace"
