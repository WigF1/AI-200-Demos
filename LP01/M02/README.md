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

## This module runs standalone

You don't need to run `LP01/M01` first. Every script here sources
`00-ensure-prereqs`, which checks whether the resource group, ACR, and
`inference-api:v1` image already exist and creates/builds whatever's
missing. If `M01` already ran, this is a fast no-op; if it didn't, this
module builds what it needs on the fly.

## Cost note: App Service plan is P0V3, not Basic

`02-configure-app-settings` creates a deployment slot, and Basic tier
doesn't support deployment slots at all - only Standard, Premium, or
Isolated do. The plan is created (or, if you already ran `01` before this
was fixed, upgraded on re-run) as `P0V3`, the cheapest SKU that supports
slots. This costs meaningfully more than Basic while it's running -
run `99-cleanup.sh` promptly when you're done for the day.

## Demo scripts

| Script | Slide touch point |
|---|---|
| `00-ensure-prereqs` | Idempotently creates the RG/ACR/image if `M01` hasn't run — makes this module self-contained (sourced automatically by the scripts below) |
| `01-deploy-app-service` | Slide 16-17: deploy from ACR, managed identity + AcrPull, `WEBSITES_PORT`; waits out RBAC propagation and polls `/health` (checking the response body, not just the status code — App Service serves its own HTTP 200 placeholder page while a container is starting) until it's genuinely up |
| `02-configure-app-settings` | Slide 18: app settings, Key Vault reference, deployment slot + slot setting; grants the caller (you) Key Vault Secrets Officer before writing the secret (RBAC-mode vaults don't grant the creator any data-plane rights), then grants the web app's identity Key Vault Secrets User and confirms the reference actually resolves |
| `03-verify-troubleshoot` | Slide 19: log stream, health check, Kudu links |
| `04-break-fix-demo` | Slide 19: live break/fix walkthrough — actually breaks `WEBSITES_PORT`, confirms the failure, fixes it, confirms recovery |
| `05-sidecar-deploy` | Lab 03: add a sidecar container (log-forwarder style) alongside the main app container; confirms the main app still serves traffic afterward |
| `99-cleanup` | Removes what this module created (web app, plan, Key Vault, sidecar, slot); leaves the resource group + ACR from `M01` in place |

## Run it

```bash
cd demo/scripts
./01-deploy-app-service.sh
./02-configure-app-settings.sh
./03-verify-troubleshoot.sh
./04-break-fix-demo.sh
./05-sidecar-deploy.sh
```

## Cleaning up

```bash
./99-cleanup.sh              # removes only what M02 created
```

To remove everything in LP01 (both modules), run `LP01/99-cleanup-all.sh` instead.
