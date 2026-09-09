# LP03 — Deploy and monitor applications on Azure Kubernetes Service

Source deck: `AI-200T00A-ENU-PowerPoint_03.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Deploy applications to Azure Kubernetes Service | [01-aks-deploy-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/01-aks-deploy-container.md) |
| [M02](./M02) | Configure applications on Azure Kubernetes Service | [02-aks-configure-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/02-aks-configure-container.md) |
| [M03](./M03) | Monitor and troubleshoot applications on Azure Kubernetes Service | [03-aks-troubleshoot-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/03-aks-troubleshoot-container.md) |

Deploys the shared demo app in [`/shared/inference-api`](../shared/inference-api)
as a Kubernetes Deployment + Service. Each module is self-contained -
`00-ensure-prereqs` bootstraps the cluster/ACR/base deployment if an
earlier module hasn't run (this can take 5-10 minutes cold, since it
includes creating the AKS cluster). Running M01 → M02 → M03 in order is
still the natural, faster path, but it's not required.

## Requires `kubectl`

Every module checks for `kubectl` up front (before creating anything) and
fails fast with instructions if it's missing, since `az aks create`
doesn't install it for you. Install it with `az aks install-cli`, or via
your OS package manager.

## Two resource groups per cluster - this is normal

Every AKS cluster creates a second, auto-managed resource group named
`MC_<your-resource-group>_<cluster-name>_<region>`, holding the actual
node infrastructure (VMSS, load balancer, NSGs). You don't create or
manage this directly, and there's no way to avoid it. Both `99-cleanup.sh`
(`az aks delete`) and the LP-level `99-cleanup-all.sh` (`az group delete`
on the resource group you created) clean it up automatically - confirmed
against Microsoft's own AKS FAQ: "When you delete your cluster, the node
resource group and all its resources are also deleted." Don't delete the
`MC_...` group manually/separately - doing so before the cluster finishes
its own teardown is a documented way to get a cluster stuck in a
permanently undeletable state.
