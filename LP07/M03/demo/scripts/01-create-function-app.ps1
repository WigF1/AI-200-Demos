# Slide 30: Flex Consumption plan - per-function scaling, scales to zero.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az storage account show --resource-group $ResourceGroup --name $StorageAccount --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Storage account '$StorageAccount' already exists."
} else {
    az storage account create `
      --resource-group $ResourceGroup --name $StorageAccount `
      --location $Location --sku Standard_LRS --output table
}

Write-Host "== Flex Consumption plan - querying the currently-supported Python version rather than hardcoding one =="
# Confirmed against Microsoft's own docs that supported Flex Consumption
# runtime versions change over time and vary by region (their own
# "how-to" doc's prose lags behind what the dynamic lookup actually
# returns) - querying it directly avoids shipping a version number that
# quietly stops being supported.
$PythonVersions = az functionapp list-flexconsumption-runtimes --location $Location --runtime python --query "[].version" --output tsv
$PythonVersion = ($PythonVersions | Sort-Object { [version]$_ } | Select-Object -Last 1)
Write-Host "Using Python $PythonVersion (highest version currently supported for Flex Consumption in $Location)"

az functionapp show --resource-group $ResourceGroup --name $FunctionApp --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Function app '$FunctionApp' already exists."
} else {
    Invoke-TimedStep "Function App create (Flex Consumption)" {
        az functionapp create `
          --resource-group $ResourceGroup --name $FunctionApp `
          --storage-account $StorageAccount `
          --flexconsumption-location $Location `
          --runtime python --runtime-version $PythonVersion `
          --os-type Linux `
          --output table
    }
}

Write-Host "== Managed identity for identity-based Service Bus / Key Vault connections (Slide 35) =="
$PrincipalId = az functionapp identity assign --resource-group $ResourceGroup --name $FunctionApp `
  --query principalId --output tsv
Write-Host "System-assigned identity: $PrincipalId"

Write-Host "== Service Bus trigger wiring: queue, RBAC, app setting (Slide 33, 35) =="
# function_app.py's trigger uses connection="ServiceBusConnection" with no
# secret - the host resolves ServiceBusConnection__fullyQualifiedNamespace
# and authenticates as the app's managed identity. That needs all three of
# these; without them the app deploys fine but the trigger never fires.
az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Service Bus namespace '$SbNamespace' not found - run LP07/M01/demo/scripts/01-create-servicebus.ps1 first."
    exit 1
}
az servicebus queue show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $JobsQueue --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Queue '$JobsQueue' already exists."
} else {
    az servicebus queue create --resource-group $ResourceGroup --namespace-name $SbNamespace `
      --name $JobsQueue --output none
    Write-Host "Created queue '$JobsQueue'."
}
$SbId = az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --query id --output tsv
$Existing = az role assignment list --assignee $PrincipalId --scope $SbId --role "Azure Service Bus Data Receiver" --query "[].id" --output tsv
if ($Existing) {
    Write-Host "Function app identity already has Azure Service Bus Data Receiver."
} else {
    # --assignee-principal-type avoids a Graph lookup that can fail for a
    # just-created identity that hasn't replicated yet.
    az role assignment create --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal `
      --role "Azure Service Bus Data Receiver" --scope $SbId --output none
    Write-Host "Granted Azure Service Bus Data Receiver to the function app identity."
}
az functionapp config appsettings set --resource-group $ResourceGroup --name $FunctionApp `
  --settings "ServiceBusConnection__fullyQualifiedNamespace=$SbNamespace.servicebus.windows.net" --output none
Write-Host "Set ServiceBusConnection__fullyQualifiedNamespace=$SbNamespace.servicebus.windows.net"

Write-Host "Function app: https://$FunctionApp.azurewebsites.net"

Write-ElapsedTime
