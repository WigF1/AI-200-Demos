# LP01 — Implement container application hosting on Azure

Source deck: `AI-200T00A-ENU-PowerPoint_01.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Store and manage containers in Azure Container Registry | [01-acr-tasks.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/01-acr-tasks.md) |
| [M02](./M02) | Deploy containers to Azure App Service (+ sidecar containers) | [02-app-svc-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/02-app-svc-container.md), [03-app-svc-sidecar.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/03-app-svc-sidecar.md) |

Both modules deploy the shared demo app in [`/shared/inference-api`](../shared/inference-api).

Each module is self-contained — `M02` doesn't require `M01` to have run
first; it will build/push the image itself via its `00-ensure-prereqs`
script if needed. Running `M01` before `M02` is still the natural order
(and the faster path, since `M02`'s prereq check becomes a no-op), but
it's not required.

## Cleaning up

Each module has its own `demo/scripts/99-cleanup.sh`/`.ps1` that removes
only what that module created. To remove everything LP01 created in one
step (both modules, entire resource group), run:

```bash
./99-cleanup-all.sh          # or .ps1
```
