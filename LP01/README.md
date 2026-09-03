# LP01 — Implement container application hosting on Azure

Source deck: `AI-200T00A-ENU-PowerPoint_01.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Store and manage containers in Azure Container Registry | [01-acr-tasks.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/01-acr-tasks.md) |
| [M02](./M02) | Deploy containers to Azure App Service (+ sidecar containers) | [02-app-svc-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/02-app-svc-container.md), [03-app-svc-sidecar.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/03-app-svc-sidecar.md) |

Both modules deploy the shared demo app in [`/shared/inference-api`](../shared/inference-api).

Run order: `LP01/M01` scripts first (build & publish the image to ACR), then
`LP01/M02` scripts (deploy that image to App Service, including the sidecar
variant).
