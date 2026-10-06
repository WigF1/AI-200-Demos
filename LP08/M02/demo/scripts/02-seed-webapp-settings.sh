#!/usr/bin/env bash
# Seeds the keys the demo/webapp dynamic-refresh demo reads (no label).
# Re-run any time to reset them to these starting values before a demo.
set -euo pipefail
SUFFIX="${SUFFIX:-ai200lp08}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-ai200-lp08-secrets-config}"
APPCONFIG_NAME="appcs-${SUFFIX}"

if ! az appconfig show --resource-group "$RESOURCE_GROUP" --name "$APPCONFIG_NAME" --output none 2>/dev/null; then
  echo "App Configuration store '$APPCONFIG_NAME' not found - run ./01-create-app-configuration.sh first." >&2
  exit 1
fi

echo "== Web app settings: TestingApp:DefaultSettings:* =="
set_kv() {
  az appconfig kv set --name "$APPCONFIG_NAME" --key "TestingApp:DefaultSettings:$1" --value "$2" --yes --output none
  echo "  TestingApp:DefaultSettings:$1 = $2"
}
set_kv Color "goldenrod"
set_kv Font "Arial"
set_kv Message "Hello from Azure App Configuration"
set_kv FestiveColor "lightgreen"
# The sentinel - the only key the app watches. Its value is arbitrary;
# what matters is that it CHANGES (e.g. 1 -> 2) after editing other keys.
set_kv HasChanged "1"

echo "== Feature flag 'xmas' (off) =="
az appconfig feature set --name "$APPCONFIG_NAME" --feature xmas --yes --output none
az appconfig feature disable --name "$APPCONFIG_NAME" --feature xmas --yes --output none
echo "  xmas = off"

ENDPOINT=$(az appconfig show --resource-group "$RESOURCE_GROUP" --name "$APPCONFIG_NAME" --query endpoint --output tsv)
echo
echo "export APPCONFIG_ENDPOINT=\"$ENDPOINT\""
echo "(paste the line above into your shell, then: cd ../webapp && dotnet run)"
