# LP08 / M01 — Manage application secrets with Azure Key Vault

**Lab:** [01-aks-retrieve-secrets.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/app-sec-config/01-aks-retrieve-secrets.md)

(Despite the filename, this lab is about retrieving Key Vault secrets from
an application — not AKS-specific; see the lab for the exact scenario.)

## Learning objectives (from the deck)
- Explain Key Vault object types (secrets, keys, certificates) and when to use each
- Retrieve secrets with the SDK using managed identity authentication
- Handle secret versioning/rotation for zero-downtime credential updates
- Implement caching strategies to reduce Key Vault API calls

## Contents

- `demo/scripts/01-create-keyvault` (bash/ps1) — Slide 6: vault, RBAC role assignment (Secrets User)
- `demo/python/retrieve_secrets.py` — Slide 7-8: `SecretClient`, versioning, error-handling decisions
- `demo/python/cached_secret_client.py` — Slide 9: time-based cache with TTL

## Run it

```bash
cd demo/scripts && ./01-create-keyvault.sh   # or .ps1
cd ../python && pip install azure-keyvault-secrets azure-identity && python retrieve_secrets.py
```
