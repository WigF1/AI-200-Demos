# Slide 31: local dev with Core Tools + Azurite. Prepares everything
# `func start` needs that isn't in the repo:
#   - the document-jobs queue the Service Bus trigger listens on (on the
#     LP07/M01 namespace - run M01's 01-create-servicebus first)
#   - Azure Service Bus Data Receiver for YOU on that namespace: the
#     trigger connects identity-based (ServiceBusConnection__fully
#     QualifiedNamespace), which locally means your az login identity.
#     Owner/Contributor are control-plane only and don't grant this.
#   - local.settings.json, from local.settings.json.example with the real
#     namespace filled in. It's gitignored (it holds secrets in real
#     projects), so a fresh clone doesn't have one - and `func start`
#     without one generates an encrypted stub with no AzureWebJobsStorage.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Service Bus namespace '$SbNamespace' not found - run LP07/M01/demo/scripts/01-create-servicebus.ps1 first."
    exit 1
}

Write-Host "== Queue '$JobsQueue' for the Service Bus trigger (Slide 33) =="
az servicebus queue show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $JobsQueue --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Queue '$JobsQueue' already exists."
} else {
    az servicebus queue create --resource-group $ResourceGroup --namespace-name $SbNamespace `
      --name $JobsQueue --output none
    Write-Host "Created queue '$JobsQueue'."
}

Write-Host "== Azure Service Bus Data Receiver for the signed-in user (identity-based connection) =="
$SbId = az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --query id --output tsv
$Me = az ad signed-in-user show --query id --output tsv
$Existing = az role assignment list --assignee $Me --scope $SbId --role "Azure Service Bus Data Receiver" --query "[].id" --output tsv
if ($Existing) {
    Write-Host "Role already assigned."
} else {
    az role assignment create --assignee-object-id $Me --assignee-principal-type User `
      --role "Azure Service Bus Data Receiver" --scope $SbId --output none
    Write-Host "Assigned. RBAC can take a few minutes to apply - early 'Unauthorized' errors from the trigger are expected."
}

Write-Host "== local.settings.json =="
$Settings = "../function-app/local.settings.json"
if ((Test-Path $Settings) -and -not (Select-String -Path $Settings -Pattern '"IsEncrypted": true' -Quiet)) {
    Write-Host "$Settings already exists - left unchanged."
} else {
    # A missing file, or the encrypted stub `func start` generates when there
    # isn't one (it only has FUNCTIONS_WORKER_RUNTIME, so it's safe to replace).
    (Get-Content ../function-app/local.settings.json.example -Raw).Replace("sb-<suffix>", $SbNamespace) |
      Set-Content -NoNewline $Settings
    Write-Host "Wrote $Settings (namespace $SbNamespace.servicebus.windows.net)."
}

Write-Host ""
Write-Host "Next: start Azurite (AzureWebJobsStorage=UseDevelopmentStorage=true) in another terminal:"
Write-Host "  npx azurite --location ~/.azurite --silent"
Write-Host "then: cd ../function-app && func start"

Write-ElapsedTime
