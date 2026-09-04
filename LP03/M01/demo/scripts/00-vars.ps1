$ErrorActionPreference = "Stop"

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Unlike the bash version this
# isn't automatic on every exit path - each script's final line calls
# Write-ElapsedTime to print it on the success path.
. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer
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
