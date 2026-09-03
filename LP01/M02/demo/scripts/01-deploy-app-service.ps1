# Slide 15-17: custom Linux container from ACR, managed identity + AcrPull, WEBSITES_PORT, health check.
Set-Location $PSScriptRoot
. ./00-vars.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv
$ImageRef = "$LoginServer/${ImageName}:${ImageTag}"

az appservice plan create --resource-group $ResourceGroup --name $AppServicePlan `
  --is-linux --sku $WebAppSku --output table

az webapp create --resource-group $ResourceGroup --plan $AppServicePlan `
  --name $WebAppName --deployment-container-image-name $ImageRef --output table

az webapp identity assign --resource-group $ResourceGroup --name $WebAppName --output table
$PrincipalId = az webapp identity show --resource-group $ResourceGroup --name $WebAppName --query principalId --output tsv
$AcrId = az acr show --name $AcrName --query id --output tsv

az role assignment create --assignee $PrincipalId --scope $AcrId --role "AcrPull"

az webapp config set --resource-group $ResourceGroup --name $WebAppName `
  --generic-configurations '{\"acrUseManagedIdentityCreds\": true}'

az webapp config appsettings set --resource-group $ResourceGroup --name $WebAppName `
  --settings WEBSITES_PORT=8000

az webapp config set --resource-group $ResourceGroup --name $WebAppName --always-on true
az webapp config set --resource-group $ResourceGroup --name $WebAppName `
  --generic-configurations '{\"healthCheckPath\": \"/health\"}'

az webapp restart --resource-group $ResourceGroup --name $WebAppName
$Host2 = az webapp show -g $ResourceGroup -n $WebAppName --query defaultHostName -o tsv
Write-Host "https://$Host2/health"
