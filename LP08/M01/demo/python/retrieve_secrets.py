"""
LP08 / M01 - Retrieve secrets from Azure Key Vault with the SDK

Demonstrates (mapped to deck slides):
  - Slide 7: SecretClient with DefaultAzureCredential (managed identity in
    Azure, your az login locally); get_secret() metadata
  - Slide 7: error-handling decisions (config error vs. auth/server error
    vs. transient network error)
  - Slide 8: versioning - set_secret creates a new version, get_secret
    returns the latest by default, or a specific version on request

Requires:
  pip install azure-keyvault-secrets azure-identity
  export KEYVAULT_URL=https://kv-<suffix>.vault.azure.net/
"""
import os

from azure.core.exceptions import HttpResponseError, ResourceNotFoundError, ServiceRequestError
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = os.environ["KEYVAULT_URL"]
client = SecretClient(vault_url=VAULT_URL, credential=DefaultAzureCredential())


def demo_get_secret_with_metadata():
    secret = client.get_secret("openai-api-key")
    print(f"value length={len(secret.value)}, version={secret.properties.version}, "
          f"created={secret.properties.created_on}")


def demo_error_handling(name: str):
    try:
        client.get_secret(name)
    except ResourceNotFoundError:
        print(f"'{name}' not found - configuration error, do not retry")
    except HttpResponseError:
        print(f"Auth or server failure retrieving '{name}' - check RBAC role assignments")
    except ServiceRequestError:
        print(f"Transient network issue retrieving '{name}' - safe to retry with backoff")


def demo_versioning():
    # Slide 8: each set_secret() creates a new version.
    v1 = client.set_secret("db-key", "old-value")
    v2 = client.set_secret("db-key", "new-value")

    latest = client.get_secret("db-key")
    print(f"Latest version returned: {latest.properties.version} (matches v2: {latest.properties.version == v2.properties.version})")

    old = client.get_secret("db-key", version=v1.properties.version)
    print(f"Explicit old version fetch still works: value length={len(old.value)}")


if __name__ == "__main__":
    demo_get_secret_with_metadata()
    demo_error_handling("this-secret-does-not-exist")
    demo_versioning()
