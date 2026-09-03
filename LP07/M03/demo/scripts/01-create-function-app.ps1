# Slide 30: Flex Consumption plan - per-function scaling, scales to zero.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp07" }
if (-not $Location) { $Location = "australiaeast" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }
$StorageAccount = "st$Suffix"
$FunctionApp = "func-$Suffix"

az group create --name $ResourceGroup --location $Location --output table

az storage account create `
  --resource-group $ResourceGroup --name $StorageAccount `
  --location $Location --sku Standard_LRS --output table

Write-Host "== Flex Consumption plan, Python 3.12 =="
az functionapp create `
  --resource-group $ResourceGroup --name $FunctionApp `
  --storage-account $StorageAccount `
  --flexconsumption-location $Location `
  --runtime python --runtime-version 3.12 `
  --os-type Linux `
  --output table

Write-Host "== Managed identity for identity-based connections =="
az functionapp identity assign --resource-group $ResourceGroup --name $FunctionApp --output table

Write-Host "Function app: https://$FunctionApp.azurewebsites.net"
