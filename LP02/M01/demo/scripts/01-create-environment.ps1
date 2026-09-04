# Slide 6: Container Apps environment - shared networking + logging boundary.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.OperationalInsights --wait
az extension add --name containerapp --upgrade --only-show-errors

az monitor log-analytics workspace show --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Log Analytics workspace '$LogAnalyticsWorkspace' already exists."
} else {
    az monitor log-analytics workspace create `
      --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --output table
}

$LawId = az monitor log-analytics workspace show --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query customerId --output tsv
$LawKey = az monitor log-analytics workspace get-shared-keys --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query primarySharedKey --output tsv

az containerapp env show --name $AcaEnv --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Container Apps environment '$AcaEnv' already exists."
} else {
    az containerapp env create `
      --name $AcaEnv --resource-group $ResourceGroup --location $Location `
      --logs-workspace-id $LawId --logs-workspace-key $LawKey --output table
}

az acr show --name $AcrName --resource-group $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "ACR '$AcrName' already exists."
} else {
    az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard --admin-enabled false --output table
}

az acr repository show --name $AcrName --image "${ImageName}:${ImageTag}" --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Image '${ImageName}:${ImageTag}' already in '$AcrName'."
} else {
    az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir
}
