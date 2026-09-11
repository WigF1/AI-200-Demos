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
az functionapp identity assign --resource-group $ResourceGroup --name $FunctionApp --output table

Write-Host "Function app: https://$FunctionApp.azurewebsites.net"

Write-ElapsedTime
