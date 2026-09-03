# LP03 / M01 — Deploy applications to Azure Kubernetes Service

**Lab:** [01-aks-deploy-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/01-aks-deploy-container.md)

## Learning objectives (from the deck)
- Explain how Deployments, Services, and Pods work together in AKS
- Create Kubernetes Deployment manifests to define how apps run
- Write Service manifests to expose applications internally/externally
- Use `kubectl` to deploy manifests and verify apps are running
- Troubleshoot common deployment issues using `kubectl`

## Contents

- `demo/manifests/deployment.yaml` — Slide 6: Deployment manifest for `inference-api`
- `demo/manifests/service-loadbalancer.yaml` — Slide 7: `LoadBalancer` Service (production, external)
- `demo/manifests/service-clusterip.yaml` — Slide 7: `ClusterIP` Service (internal-only, for comparison)
- `demo/scripts/01-create-aks-cluster` — Slide 5: managed control plane, attach ACR
- `demo/scripts/02-deploy-manifests` — Slide 8: apply manifests, verification order (Pod → Service → logs)
- `demo/scripts/03-troubleshoot-common-failures` — Slide 8: `ImagePullBackOff` / `CrashLoopBackOff` / `Pending` / no-endpoints demo
