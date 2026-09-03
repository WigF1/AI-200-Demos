# Slide 5, 7: Standard tier namespace, one queue, one topic + 2 subscriptions.
$ErrorActionPreference = "Stop"
if (-not $Suffix) { $Suffix = "ai200lp07" }
if (-not $Location) { $Location = "eastus" }
if (-not $ResourceGroup) { $ResourceGroup = "rg-ai200-lp07-integrate" }
$SbNamespace = "sb-$Suffix"
$QueueName = "inference-requests"
$TopicName = "inference-results"

az group create --name $ResourceGroup --location $Location --output table

az servicebus namespace create `
  --resource-group $ResourceGroup --name $SbNamespace `
  --sku Standard --location $Location --output table

Write-Host "== Queue: point-to-point, competing consumers =="
az servicebus queue create `
  --resource-group $ResourceGroup --namespace-name $SbNamespace --name $QueueName `
  --max-delivery-count 5 --enable-dead-lettering-on-message-expiration true `
  --output table

Write-Host "== Topic + 2 subscriptions: fan-out =="
az servicebus topic create `
  --resource-group $ResourceGroup --namespace-name $SbNamespace --name $TopicName `
  --output table
az servicebus topic subscription create `
  --resource-group $ResourceGroup --namespace-name $SbNamespace --topic-name $TopicName `
  --name notifications --output table
az servicebus topic subscription create `
  --resource-group $ResourceGroup --namespace-name $SbNamespace --topic-name $TopicName `
  --name audit --output table

Write-Host "== Connection string for the Python scripts =="
az servicebus namespace authorization-rule keys list `
  --resource-group $ResourceGroup --namespace-name $SbNamespace `
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv
