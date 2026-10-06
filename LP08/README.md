# LP08 — Manage application secrets and configuration for AI solutions

Source deck: `AI-200T00A-ENU-PowerPoint_08.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Manage application secrets with Azure Key Vault | [01-aks-retrieve-secrets.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/app-sec-config/01-aks-retrieve-secrets.md) |
| [M02](./M02) | Manage application settings with Azure App Configuration | [02-exercise-retrieve-settings.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/app-sec-config/02-exercise-retrieve-settings.md) |

Each module has `demo/scripts` (bash + PowerShell provisioning) and
`demo/python` (SDK scripts for the actual retrieval/caching/reference work).
M02 also has `demo/webapp` (ASP.NET Core dynamic refresh demo).

## Cleanup

Both modules share resource group `rg-ai200-lp08-secrets-config`.
`99-cleanup-all.sh`/`.ps1` deletes it after a typed confirmation. First it
deletes **and purges** Key Vault `kv-<suffix>`: soft-delete would
otherwise hold the vault's globally unique name for 90 days, and M01's
`01-create-keyvault` would fail on the next run.
