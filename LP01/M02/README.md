# LP01 / M02 — Deploy containers to Azure App Service

**Labs:**
- [02-app-svc-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/02-app-svc-container.md)
- [03-app-svc-sidecar.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/03-app-svc-sidecar.md)

## Learning objectives (from the deck)
- Deploy custom containers to App Service from container registries
- Configure runtime behavior: startup commands, port settings, persistent storage
- Configure app settings and connection strings
- Observe/troubleshoot containerized apps with App Service diagnostics
- (Lab 03) Run a multi-container app using **sidecar containers**

## Demo scripts

| Script | Slide touch point |
|---|---|
| `01-deploy-app-service` | Slide 16-17: deploy from ACR, managed identity + AcrPull, `WEBSITES_PORT` |
| `02-configure-app-settings` | Slide 18: app settings, Key Vault reference, deployment slot + slot setting |
| `03-verify-troubleshoot` | Slide 19: log stream, health check, live break/fix demo |
| `04-sidecar-deploy` | Lab 03: add a sidecar container (log-forwarder style) alongside the main app container |

## Run it

```bash
cd demo/scripts
./01-deploy-app-service.sh
./02-configure-app-settings.sh
./03-verify-troubleshoot.sh
./04-sidecar-deploy.sh
```

Requires LP01/M01 to have already pushed `inference-api:v1` to ACR.
