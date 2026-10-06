# Slide 5, 7: Standard tier namespace, one queue (point-to-point) and one
# topic + two subscriptions (fan-out).
Set-Location $PSScriptRoot
. ./00-vars.ps1

az group show --name $ResourceGroup --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource group '$ResourceGroup' already exists."
} else {
    az group create --name $ResourceGroup --location $Location --output table
}

az servicebus namespace show --resource-group $ResourceGroup --name $SbNamespace --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Service Bus namespace '$SbNamespace' already exists."
} else {
    Invoke-TimedStep "Service Bus namespace create" {
        az servicebus namespace create `
          --resource-group $ResourceGroup --name $SbNamespace `
          --sku Standard --location $Location --output table
    }
}

Write-Host "== Queue: point-to-point, competing consumers (Slide 7) =="
az servicebus queue show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $QueueName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Queue '$QueueName' already exists."
} else {
    az servicebus queue create `
      --resource-group $ResourceGroup --namespace-name $SbNamespace --name $QueueName `
      --max-delivery-count 5 --enable-dead-lettering-on-message-expiration true `
      --output table
}

Write-Host "== Topic + 2 subscriptions: fan-out (Slide 7, knowledge check Q1) =="
az servicebus topic show --resource-group $ResourceGroup --namespace-name $SbNamespace --name $TopicName --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Topic '$TopicName' already exists."
} else {
    az servicebus topic create `
      --resource-group $ResourceGroup --namespace-name $SbNamespace --name $TopicName `
      --output table
}
foreach ($sub in @("notifications", "audit")) {
    az servicebus topic subscription show --resource-group $ResourceGroup --namespace-name $SbNamespace `
      --topic-name $TopicName --name $sub --output none 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subscription '$sub' already exists."
    } else {
        az servicebus topic subscription create `
          --resource-group $ResourceGroup --namespace-name $SbNamespace --topic-name $TopicName `
          --name $sub --output table
    }
}

Write-Host "== Subscription filter: audit only gets results flagged requires_audit (Slide 7) =="
# Every subscription starts with a $Default rule (SQL filter 1=1, i.e.
# "everything"). notifications keeps it; audit swaps it for a SQL filter
# on the requires_audit application property, so it gets a subset. Create
# the new rule BEFORE deleting $Default - a subscription with no rules
# receives nothing. Re-runnable: both steps are skipped once done.
$AuditRules = az servicebus topic subscription rule list --resource-group $ResourceGroup `
  --namespace-name $SbNamespace --topic-name $TopicName --subscription-name audit `
  --query "[].name" --output tsv
if (-not ($AuditRules -contains "requires-audit")) {
    az servicebus topic subscription rule create --resource-group $ResourceGroup `
      --namespace-name $SbNamespace --topic-name $TopicName --subscription-name audit `
      --name requires-audit --filter-sql-expression "requires_audit = TRUE" --output none
    Write-Host "Added rule 'requires-audit' to subscription 'audit'."
}
if ($AuditRules -contains '$Default') {
    az servicebus topic subscription rule delete --resource-group $ResourceGroup `
      --namespace-name $SbNamespace --topic-name $TopicName --subscription-name audit `
      --name '$Default'
    Write-Host "Removed the match-all `$Default rule from subscription 'audit'."
}

Write-Host ""
Write-Host "== Connection string for the Python scripts =="
$ConnStr = az servicebus namespace authorization-rule keys list `
  --resource-group $ResourceGroup --namespace-name $SbNamespace `
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv
Write-Host "`$env:SERVICEBUS_CONNECTION_STRING = `"$ConnStr`""
Write-Host "(paste the line above into your shell before running any of the Python demos)"

Write-ElapsedTime
