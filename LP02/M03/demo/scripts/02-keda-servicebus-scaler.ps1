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

# Confirmed against Microsoft's own tutorial: "When you use the Azure CLI
# to add a scale rule to a container app that already has a scale rule,
# the new scale rule replaces the old scale rule." A plain
# `az containerapp update --scale-rule-name ...` here would silently
# delete 01-http-scale-rule.ps1's rule instead of adding alongside it -
# defeating the deck's own "multiple rules use the highest replica count"
# point, and meaning 01/02/04/05 could never all work without re-running
# each other.
#
# Rather than hand-write the azure-servicebus rule's YAML schema from
# memory (a mistake made twice already with other Container Apps/sidecar
# schemas this session), this lets the CLI itself generate the correct
# rule shape - via the same replacing update - then splices that
# CLI-generated rule into whatever rules already existed, and reapplies
# the merged result. Needs PyYAML; degrades to the old replacing
# behavior (with a clear warning) if it's not available.
az containerapp show --name $AcaApp --resource-group $ResourceGroup --output yaml | Out-File -FilePath /tmp/aca-before.yaml -Encoding utf8

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -ne 0) {
    pip install --quiet --user pyyaml 2>$null
    if ($LASTEXITCODE -ne 0) { pip install --quiet --break-system-packages pyyaml 2>$null }
}

python3 -c "import yaml" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "PyYAML not available - falling back to a plain update, which WILL remove any"
    Write-Warning "other scale rule already on this app (e.g. http-scale-rule from 01)."
    az containerapp update --name $AcaApp --resource-group $ResourceGroup `
      --min-replicas 0 --max-replicas 5 `
      --scale-rule-name servicebus-queue-scale `
      --scale-rule-type azure-servicebus `
      --scale-rule-metadata "queueName=$ServiceBusQueue" "namespace=$ServiceBusNamespace" "messageCount=5" `
      --scale-rule-auth "connection=servicebus-connection" `
      --output table
    Write-ElapsedTime
    exit 0
}

$extractScript = @'
import yaml
with open("/tmp/aca-before.yaml") as f:
    before = yaml.safe_load(f)
scale = (before.get("properties", {}).get("template", {}) or {}).get("scale", {}) or {}
existing_rules = scale.get("rules", []) or []
preserved = [r for r in existing_rules if r.get("name") != "servicebus-queue-scale"]
with open("/tmp/preserved-rules.yaml", "w") as f:
    yaml.safe_dump({"preserved": preserved, "priorMaxReplicas": scale.get("maxReplicas")}, f)
'@
$extractScriptPath = "$env:TEMP\extract-rules.py"
Set-Content -Path $extractScriptPath -Value $extractScript
python3 $extractScriptPath

az containerapp update --name $AcaApp --resource-group $ResourceGroup `
  --min-replicas 0 --max-replicas 5 `
  --scale-rule-name servicebus-queue-scale `
  --scale-rule-type azure-servicebus `
  --scale-rule-metadata "queueName=$ServiceBusQueue" "namespace=$ServiceBusNamespace" "messageCount=5" `
  --scale-rule-auth "connection=servicebus-connection" `
  --output none

az containerapp show --name $AcaApp --resource-group $ResourceGroup --output yaml | Out-File -FilePath /tmp/aca-after.yaml -Encoding utf8

$mergeScript = @'
import yaml
with open("/tmp/aca-after.yaml") as f:
    after = yaml.safe_load(f)
with open("/tmp/preserved-rules.yaml") as f:
    preserved_data = yaml.safe_load(f)

scale = after["properties"]["template"]["scale"]
new_rules = scale.get("rules", []) or []
merged = preserved_data["preserved"] + new_rules
scale["rules"] = merged

prior_max = preserved_data.get("priorMaxReplicas")
if isinstance(prior_max, int) and prior_max > scale.get("maxReplicas", 0):
    scale["maxReplicas"] = prior_max

with open("/tmp/aca-merged.yaml", "w") as f:
    yaml.safe_dump(after, f, default_flow_style=False)
'@
$mergeScriptPath = "$env:TEMP\merge-rules.py"
Set-Content -Path $mergeScriptPath -Value $mergeScript
python3 $mergeScriptPath

Write-Host "== Reapplying merged config so both scale rules coexist =="
az containerapp update --name $AcaApp --resource-group $ResourceGroup --yaml /tmp/aca-merged.yaml --output table

Write-Host "== Confirming both rules are present =="
az containerapp show --name $AcaApp --resource-group $ResourceGroup --query "properties.template.scale" --output json

Write-ElapsedTime
