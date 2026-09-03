# Slide 6: Container Apps environment - shared networking + logging boundary.
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group create --name $ResourceGroup --location $Location --output table
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights
az extension add --name containerapp --upgrade --only-show-errors

az monitor log-analytics workspace create `
  --resource-group $ResourceGroup --workspace-name $LogAnalyticsWorkspace --output table

$LawId = az monitor log-analytics workspace show --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query customerId --output tsv
$LawKey = az monitor log-analytics workspace get-shared-keys --resource-group $ResourceGroup `
  --workspace-name $LogAnalyticsWorkspace --query primarySharedKey --output tsv

az containerapp env create `
  --name $AcaEnv --resource-group $ResourceGroup --location $Location `
  --logs-workspace-id $LawId --logs-workspace-key $LawKey --output table

az acr create --resource-group $ResourceGroup --name $AcrName --sku Standard --admin-enabled false --output table
az acr build --registry $AcrName --image "${ImageName}:${ImageTag}" --file "$AppDir/Dockerfile" $AppDir
