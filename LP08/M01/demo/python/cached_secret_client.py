"""
LP08 / M01 - Time-based caching for Key Vault secrets (Slide 9)

Why: Key Vault throttles at 4,000 GET per vault per 10-second window. A
high-throughput inference service that fetched the API key on every
request would blow through that. Cache it in-process instead.

Requires:
  pip install azure-keyvault-secrets azure-identity
  export KEYVAULT_URL=https://kv-<suffix>.vault.azure.net/
"""
import os
import time

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = os.environ["KEYVAULT_URL"]
client = SecretClient(vault_url=VAULT_URL, credential=DefaultAzureCredential())

_cache: dict[str, dict] = {}
_ttl_seconds = 3600  # match TTL to rotation frequency: 90-day rotation -> 1-hour TTL


def get_cached_secret(name: str) -> str:
    cached = _cache.get(name)
    now = time.monotonic()
    if cached and (now - cached["ts"]) < _ttl_seconds:
        return cached["value"]

    secret = client.get_secret(name)
    _cache[name] = {"value": secret.value, "ts": now}
    return secret.value


def simulate_high_throughput_calls(n: int = 500):
    calls_to_keyvault = 0
    original_get_secret = client.get_secret

    def counting_get_secret(*args, **kwargs):
        nonlocal calls_to_keyvault
        calls_to_keyvault += 1
        return original_get_secret(*args, **kwargs)

    client.get_secret = counting_get_secret  # type: ignore[method-assign]

    for _ in range(n):
        get_cached_secret("openai-api-key")

    print(f"{n} logical calls to get_cached_secret -> {calls_to_keyvault} actual Key Vault GET(s)")


if __name__ == "__main__":
    simulate_high_throughput_calls(500)
