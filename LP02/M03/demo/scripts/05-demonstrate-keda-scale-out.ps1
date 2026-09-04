# Companion to 02-keda-servicebus-scaler.ps1: that script only CONFIGURES
# the KEDA scaler - this one actually sends messages to the queue and
# watches replicas scale up from zero, so the scaler's effect is visible.
Set-Location $PSScriptRoot
. ./00-vars.ps1
. ./00-ensure-prereqs.ps1

$hasRule = az containerapp show --name $AcaApp --resource-group $ResourceGroup `
  --query "properties.template.scale.rules[?name=='servicebus-queue-scale']" --output tsv
if (-not $hasRule) {
    Write-Error "No 'servicebus-queue-scale' scale rule found - run ./02-keda-servicebus-scaler.ps1 first."
    exit 1
}

Write-Host "== Baseline replica count (likely 0 - min-replicas is 0 for this scaler) =="
az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --output table

Write-Host ""
Write-Host "== Sending 20 messages to '$ServiceBusQueue' =="
python3 -c "import azure.servicebus" 2>$null
if ($LASTEXITCODE -ne 0) {
    pip install --quiet --user azure-servicebus 2>$null
    if ($LASTEXITCODE -ne 0) { pip install --quiet --break-system-packages azure-servicebus 2>$null }
}

$ConnString = az servicebus namespace authorization-rule keys list `
  --resource-group $ResourceGroup --namespace-name $ServiceBusNamespace `
  --name RootManageSharedAccessKey --query primaryConnectionString --output tsv

python3 -c "import azure.servicebus" 2>$null
if ($LASTEXITCODE -eq 0) {
    $pyScript = @'
import sys
from azure.servicebus import ServiceBusClient, ServiceBusMessage

conn_string, queue_name = sys.argv[1], sys.argv[2]
with ServiceBusClient.from_connection_string(conn_string) as client:
    with client.get_queue_sender(queue_name) as sender:
        messages = [ServiceBusMessage(f"scale-demo-{i}") for i in range(20)]
        sender.send_messages(messages)
print("Sent 20 messages.")
'@
    $pyScriptPath = "$env:TEMP\send-sb-messages.py"
    Set-Content -Path $pyScriptPath -Value $pyScript
    python3 $pyScriptPath $ConnString $ServiceBusQueue
} else {
    Write-Error "azure-servicebus SDK not available and couldn't be installed - can't send messages."
    Write-Error "Install it and re-run: pip install azure-servicebus"
    exit 1
}

Write-Host ""
Write-Host "== Polling replica count every 15s (KEDA polls the queue every ~30s by default) =="
for ($check = 1; $check -le 8; $check++) {
    Start-Sleep -Seconds 15
    $count = az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --query "length(@)" --output tsv
    $depth = az servicebus queue show --namespace-name $ServiceBusNamespace --resource-group $ResourceGroup `
      --name $ServiceBusQueue --query "countDetails.activeMessageCount" --output tsv
    Write-Host "  t+${check}x15s: $count replica(s), $depth message(s) still queued"
}

Write-Host ""
Write-Host "== Final state =="
az containerapp replica list --name $AcaApp --resource-group $ResourceGroup --output table
Write-Host "Once the queue drains and the cooldown period passes, replicas scale back to 0."
