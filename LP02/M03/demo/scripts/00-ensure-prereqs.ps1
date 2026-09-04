# Makes this module runnable without LP02/M01 or M02 having run first.
# Mirrors their environment + ACR + container app creation, plus creates
# a Service Bus namespace/queue for the KEDA scaler demo (02) since that
# previously assumed one already existed elsewhere. Each step checks
# existence first so this is a fast no-op when earlier modules already ran.

Write-Host "== Ensuring prerequisites for LP02/M03 (env, ACR, image, container app, Service Bus) =="

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az provider register --namespace Microsoft.ServiceBus --wait
az extension add --name containerapp --upgrade --only-show-errors

az monitor log-analytics workspace show --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    az monitor log-analytics workspace create `
      --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --output table
}
$LawId = az monitor log-analytics workspace show --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query customerId --output tsv
$LawKey = az monitor log-analytics workspace get-shared-keys --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query primarySharedKey --output tsv

$EnvState = az containerapp env show --name $AcaEnv --resource-group $ResourceGroup --query properties.provisioningState --output tsv 2>$null
if ($EnvState -eq "Succeeded") {
    Write-Host "Container Apps environment '$AcaEnv' already exists and is healthy."
} else {
    if ($EnvState) {
        Write-Host "Container Apps environment '$AcaEnv' exists but is in state '$EnvState' (not Succeeded) - deleting so it can be recreated cleanly."
        az containerapp env delete --name $AcaEnv --resource-group $ResourceGroup --yes
    }
    Write-Host "Creating Container Apps environment (can take several minutes; if this fails with a ManagedCluster/provisioning error, it's an Azure-side issue - re-running will clean up and retry)"
    Invoke-TimedStep "Container Apps environment create" {
        az containerapp env create `
          --name $AcaEnv --resource-group $ResourceGroup --location $Location `
          --logs-workspace-id $LawId --logs-workspace-key $LawKey --output table
    }
}

az acr show --name $AcrName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ACR '$AcrName' already exists."
} else {
    az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard --admin-enabled false --output table
}

az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Invoke-TimedStep "ACR build" {
        az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir
    }
}

az containerapp show --name $AcaApp --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Container app '$AcaApp' already exists."
} else {
    Write-Host "Container app '$AcaApp' not found - creating..."
    $LoginServer = az acr show --name $AcrName --query loginServer --output tsv
    az containerapp create `
      --name $AcaApp --resource-group $ResourceGroup --environment $AcaEnv `
      --image "$LoginServer/${ImageName}:${ImageTag}" `
      --target-port 8000 --ingress external `
      --registry-server $LoginServer --registry-identity system `
      --system-assigned `
      --secrets "model-api-key=demo-api-key-not-real-1234567890" `
      --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" `
                 "MODEL_API_KEY=secretref:model-api-key" `
      --min-replicas 1 --max-replicas 3 `
      --output table

    $PrincipalId = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query identity.principalId --output tsv
    $AcrId = az acr show --name $AcrName --query id --output tsv
    . "$PSScriptRoot/../../../../shared/lib/rbac-wait.ps1"
    Set-RoleAssignment -PrincipalId $PrincipalId -Scope $AcrId -Role "AcrPull"
    $LatestRevision = az containerapp revision list --name $AcaApp --resource-group $ResourceGroup --query "[0].name" --output tsv
    az containerapp revision restart --name $AcaApp --resource-group $ResourceGroup --revision $LatestRevision --output none
}

az servicebus namespace show --name $ServiceBusNamespace --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Service Bus namespace '$ServiceBusNamespace' already exists."
} else {
    az servicebus namespace create --name $ServiceBusNamespace --resource-group $ResourceGroup `
      --location $Location --sku Basic --output table
}

az servicebus queue show --namespace-name $ServiceBusNamespace --resource-group $ResourceGroup `
  --name $ServiceBusQueue --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Service Bus queue '$ServiceBusQueue' already exists."
} else {
    az servicebus queue create --namespace-name $ServiceBusNamespace --resource-group $ResourceGroup `
      --name $ServiceBusQueue --output table
}

Write-Host "Prerequisites ready."
