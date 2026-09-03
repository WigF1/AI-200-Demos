# LP08 / M02 — Manage application settings with Azure App Configuration

**Lab:** [02-exercise-retrieve-settings.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/app-sec-config/02-exercise-retrieve-settings.md)

## Learning objectives (from the deck)
- Connect to App Configuration with managed identity, retrieve settings via the Python provider
- Organize settings with labels; implement feature flags
- Reference Key Vault secrets from App Configuration
- Decide what belongs in App Configuration vs. Key Vault

## Contents

- `demo/scripts/01-create-app-configuration` (bash/ps1) — Slide 17: store, RBAC (Data Reader), labeled key-values, feature flag
- `demo/python/retrieve_settings.py` — Slide 17-18: `SettingSelector`, labels/composition, `FeatureManager`
- `demo/python/keyvault_reference.py` — Slide 19: Key Vault reference resolved through the same provider

## Run it

```bash
cd demo/scripts && ./01-create-app-configuration.sh   # or .ps1
cd ../python && pip install azure-appconfiguration-provider azure-identity && python retrieve_settings.py
```
