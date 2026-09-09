$ErrorActionPreference = "Stop"

# Track how long this script takes end-to-end - handy for comparing
# deployment times across runs/regions. Unlike the bash version this
# isn't automatic on every exit path - each script's final line calls
# Write-ElapsedTime to print it on the success path.
. "$PSScriptRoot/../../../../shared/lib/timing.ps1"
Start-ElapsedTimer

# Fail fast (before wasting minutes on AKS cluster creation, or anything
# else) if kubectl isn't installed - az CLI doesn't install it for you.
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl not found. Install it with: az aks install-cli (or via your OS package manager: https://kubernetes.io/docs/tasks/tools/)"
    exit 1
}
if (-not $Suffix) { $Suffix = "ai200lp03" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp03-aks" }
$AcrName = "acr$Suffix"
$ImageName = "inference-api"
$ImageTag = "v1"
$AppDir = "../../../../shared/inference-api"
$AksCluster = "aks-$Suffix"
$Namespace = "ai-workloads"
# For 03-keyvault-csi-integration.ps1
$KeyVaultName = "kv-$Suffix"
$KvSecretName = "model-api-key"
$SecretProviderClass = "inference-api-kv-secrets"
$SyncedSecretName = "inference-api-kv-secret"
Write-Host "ResourceGroup=$ResourceGroup  AksCluster=$AksCluster  Namespace=$Namespace"
