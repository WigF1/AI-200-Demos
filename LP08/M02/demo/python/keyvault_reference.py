"""
LP08 / M02 - Resolve a Key Vault reference through App Configuration
(Slide 19-20)

The provider resolves the App Configuration entry (a URI pointer) to the
actual secret value automatically, based on its content type - the app
reads settings and secrets through the same dictionary.

Requires two RBAC roles on the app identity (Slide 22 knowledge check):
  - "App Configuration Data Reader" on the App Configuration store
  - "Key Vault Secrets User" on the Key Vault

Requires:
  pip install azure-appconfiguration-provider azure-identity
  export APPCONFIG_ENDPOINT=https://appcs-<suffix>.azconfig.io
"""
import os

from azure.appconfiguration.provider import load
from azure.identity import DefaultAzureCredential

ENDPOINT = os.environ["APPCONFIG_ENDPOINT"]

# secret_refresh_interval controls an independent refresh cycle for
# Key-Vault-backed values, separate from regular setting refresh.
config = load(
    endpoint=ENDPOINT,
    credential=DefaultAzureCredential(),
    key_vault_options={"secret_refresh_interval": 3600},
)

if __name__ == "__main__":
    api_key = config.get("OpenAI:ApiKey")
    if api_key:
        print(f"Resolved OpenAI:ApiKey through Key Vault reference (length={len(api_key)})")
    else:
        print("OpenAI:ApiKey not found - run 01-create-app-configuration with a Key Vault present first")
