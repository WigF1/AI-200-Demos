# LP02 / M01 — Deploy containers to Azure Container Apps

**Lab:** [01-aca-deploy-containers.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-container-apps/01-aca-deploy-containers.md)

## Learning objectives (from the deck)
- Explain how Container Apps environments affect networking, logging, and isolation
- Deploy a container app using the Azure CLI, and using the CLI with a YAML definition
- Configure runtime settings using environment variables and secrets
- Configure image pull authentication for private registries
- Verify container app health using logs, revisions, and replica status

## Demo scripts

| Script | Slide touch point |
|---|---|
| `01-create-environment` | Slide 6: Container Apps environment (shared network/logging boundary) |
| `02-deploy-container-app` | Slide 7-9: `containerapp create`, managed identity + AcrPull, env vars & secrets, WEBSITES-equivalent target port |
| `03-verify-deployment` | Slide 10: logs, revisions, replicas |

Run from `demo/scripts/` — bash (`.sh`) or PowerShell (`.ps1`).
