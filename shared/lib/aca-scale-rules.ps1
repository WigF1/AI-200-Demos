# Shared helper: add or update ONE named Container Apps scale rule
# without wiping out any other scale rule already on the app.
#
# az containerapp update replaces the app's ENTIRE scale rule set by
# default - confirmed against Microsoft's own tutorial: "When you use
# the Azure CLI to add a scale rule to a container app that already has
# a scale rule, the new scale rule replaces the old scale rule." That
# means two scripts each adding a different rule (e.g. an HTTP rule and
# a Service Bus rule) will keep wiping each other out, in EITHER order,
# no matter which one runs second - a single script fixing just one
# direction isn't enough.
#
# This works around it without hand-writing any scale rule's YAML schema
# from memory: it captures whatever rules already exist, lets the CLI
# generate the new/updated rule via the same (still individually
# replacing) update call, then splices that CLI-generated rule back in
# alongside the preserved ones and reapplies the merged result.
#
# Usage: dot-source this file, then:
#   Add-OrUpdateScaleRule -App $AcaApp -ResourceGroup $ResourceGroup -RuleName "http-scale-rule" -UpdateArgs @(
#       "--min-replicas", "0", "--max-replicas", "10",
#       "--scale-rule-name", "http-scale-rule", "--scale-rule-type", "http",
#       "--scale-rule-http-concurrency", "10"
#   )
#
# -RuleName is used to find and drop any prior version of that rule
# before merging, so re-running is idempotent. -UpdateArgs is passed
# straight through to `az containerapp update`.

function Add-OrUpdateScaleRule {
    param(
        [Parameter(Mandatory = $true)][string]$App,
        [Parameter(Mandatory = $true)][string]$ResourceGroup,
        [Parameter(Mandatory = $true)][string]$RuleName,
        [Parameter(Mandatory = $true)][string[]]$UpdateArgs
    )

    az containerapp show --name $App --resource-group $ResourceGroup --output yaml | Out-File -FilePath /tmp/aca-before.yaml -Encoding utf8

    python3 -c "import yaml" 2>$null
    if ($LASTEXITCODE -ne 0) {
        pip install --quiet --user pyyaml 2>$null
        if ($LASTEXITCODE -ne 0) { pip install --quiet --break-system-packages pyyaml 2>$null }
    }

    python3 -c "import yaml" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "PyYAML not available - falling back to a plain update, which WILL remove any"
        Write-Warning "other scale rule already on this app."
        az containerapp update --name $App --resource-group $ResourceGroup @UpdateArgs --output table
        return
    }

    $extractScript = @'
import sys, yaml
rule_name = sys.argv[1]
with open("/tmp/aca-before.yaml") as f:
    before = yaml.safe_load(f)
scale = (before.get("properties", {}).get("template", {}) or {}).get("scale", {}) or {}
existing_rules = scale.get("rules", []) or []
preserved = [r for r in existing_rules if r.get("name") != rule_name]
with open("/tmp/preserved-rules.yaml", "w") as f:
    yaml.safe_dump({"preserved": preserved, "priorMaxReplicas": scale.get("maxReplicas")}, f)
'@
    $extractScriptPath = "$env:TEMP\extract-rules.py"
    Set-Content -Path $extractScriptPath -Value $extractScript
    python3 $extractScriptPath $RuleName

    az containerapp update --name $App --resource-group $ResourceGroup @UpdateArgs --output none

    az containerapp show --name $App --resource-group $ResourceGroup --output yaml | Out-File -FilePath /tmp/aca-after.yaml -Encoding utf8

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

    Write-Host "== Reapplying merged config so all scale rules coexist =="
    az containerapp update --name $App --resource-group $ResourceGroup --yaml /tmp/aca-merged.yaml --output none

    # The two update calls above go through a genuinely-different-then-
    # corrected-back-again intermediate state (first call sets ONLY the
    # new rule with its own maxReplicas, second call restores the rest) -
    # a read right after this function returns can catch that transient
    # state before it's settled rather than the final merged result. Poll
    # until the live config actually matches what we just applied.
    $countScript = @'
import yaml
with open("/tmp/aca-merged.yaml") as f:
    doc = yaml.safe_load(f)
print(len(doc["properties"]["template"]["scale"].get("rules", [])))
'@
    $countScriptPath = "$env:TEMP\count-rules.py"
    Set-Content -Path $countScriptPath -Value $countScript
    $expectedRuleCount = python3 $countScriptPath

    for ($attempt = 1; $attempt -le 6; $attempt++) {
        $liveRuleCount = az containerapp show --name $App --resource-group $ResourceGroup `
          --query "length(properties.template.scale.rules)" --output tsv
        if ($liveRuleCount -eq $expectedRuleCount) { break }
        Write-Host "  waiting for the merged config to settle (attempt $attempt`: $liveRuleCount/$expectedRuleCount rules visible)..."
        Start-Sleep -Seconds 5
    }

    Write-Host "== Confirmed final scale config =="
    az containerapp show --name $App --resource-group $ResourceGroup --query "properties.template.scale" --output json
}
