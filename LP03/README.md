# LP03 — Deploy and monitor applications on Azure Kubernetes Service

Source deck: `AI-200T00A-ENU-PowerPoint_03.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Deploy applications to Azure Kubernetes Service | [01-aks-deploy-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/01-aks-deploy-container.md) |
| [M02](./M02) | Configure applications on Azure Kubernetes Service | [02-aks-configure-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/02-aks-configure-container.md) |
| [M03](./M03) | Monitor and troubleshoot applications on Azure Kubernetes Service | [03-aks-troubleshoot-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/03-aks-troubleshoot-container.md) |

Deploys the shared demo app in [`/shared/inference-api`](../shared/inference-api)
as a Kubernetes Deployment + Service. Run M01 first (creates the AKS
cluster and the base Deployment/Service), then M02 (ConfigMaps, Secrets,
PVCs), then M03 (deliberately breaks and fixes the app for a live
troubleshooting demo).
