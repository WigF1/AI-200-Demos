# Slide 7-9: containerapp create, managed identity + AcrPull, env vars/secrets.
Set-Location $PSScriptRoot
. ./00-vars.ps1

$LoginServer = az acr show --name $AcrName --query loginServer --output tsv
$ImageRef = "$LoginServer/${ImageName}:${ImageTag}"

az containerapp create `
  --name $AcaApp --resource-group $ResourceGroup --environment $AcaEnv `
  --image $ImageRef `
  --target-port 8000 --ingress external `
  --registry-server $LoginServer --registry-identity system `
  --system-assigned `
  --secrets "model-api-key=demo-api-key-not-real-1234567890" `
  --env-vars "APP_ENVIRONMENT=production" "FEATURE_X_ENABLED=true" "MODEL_API_KEY=secretref:model-api-key" `
  --min-replicas 1 --max-replicas 3 `
  --output table

$PrincipalId = az containerapp show --name $AcaApp --resource-group $ResourceGroup --query identity.principalId --output tsv
$AcrId = az acr show --name $AcrName --query id --output tsv
az role assignment create --assignee $PrincipalId --scope $AcrId --role "AcrPull"

az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query properties.configuration.ingress.fqdn --output tsv
