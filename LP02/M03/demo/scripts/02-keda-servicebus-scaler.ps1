# Slide 31, 36: KEDA azure-servicebus scaler, scale-to-zero for queue-driven workers.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

$ConnString = az servicebus namespace authorization-rule keys list `
  --resource-group $ResourceGroup --namespace-name $ServiceBusNamespace `
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv

# az containerapp update has no --secrets parameter at all (confirmed
# against the official az containerapp reference docs) - only create and
# the dedicated `secret set` command manage secrets. Using --secrets on
# update fails with "unrecognized arguments" even though it's spelled
# correctly, because argparse doesn't know that flag for this subcommand.
az containerapp secret set --name $AcaApp --resource-group $ResourceGroup `
  --secrets "servicebus-connection=$ConnString" `
  --output none

az containerapp update --name $AcaApp --resource-group $ResourceGroup `
  --min-replicas 0 --max-replicas 5 `
  --scale-rule-name servicebus-queue-scale `
  --scale-rule-type azure-servicebus `
  --scale-rule-metadata "queueName=$ServiceBusQueue" "namespace=$ServiceBusNamespace" "messageCount=5" `
  --scale-rule-auth "connection=servicebus-connection" `
  --output table

Write-ElapsedTime
