# LP03 / M02 — Configure applications on Azure Kubernetes Service

**Lab:** [02-aks-configure-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/02-aks-configure-container.md)

## Learning objectives (from the deck)
- Externalize app configuration using Kubernetes primitives
- Implement ConfigMaps and inject settings into Pods
- Implement Secrets and consume sensitive values securely
- Attach persistent storage using PersistentVolume/PersistentVolumeClaim
- Integrate Azure Key Vault secrets into Pods via the Secrets Store CSI Driver

## Contents

- `demo/manifests/configmap.yaml` — Slide 16: non-sensitive settings
- `demo/manifests/secret.yaml` — Slide 17: sensitive values (template only — do not commit real secrets)
- `demo/manifests/pvc.yaml` — Slide 18: PersistentVolumeClaim (Azure Disk, ReadWriteOnce)
- `demo/manifests/deployment-configured.yaml` — Deployment wired to the ConfigMap, Secret, and PVC
- `demo/scripts/01-apply-config-and-secrets` — Slides 16-17: apply ConfigMap/Secret, verify injection
- `demo/scripts/02-attach-persistent-storage` — Slide 18: PVC bound status, restart-persistence test
- `demo/scripts/03-keyvault-csi-integration` — Azure Key Vault integration via the Secrets Store CSI
  Driver, using the driver's own auto-created managed identity (simpler than full Workload Identity,
  and not the deprecated "AAD Pod Identity" project). Demonstrates the retrieved secret two ways:
  mounted as a file at `/mnt/secrets-store` (`kubectl exec ... cat`), and synced to a native
  Kubernetes Secret wired into `MODEL_API_KEY` - the app's own `/config` endpoint then reports it
  exactly like it already does for the plain K8s Secret from `01`, since Key Vault now supersedes
  that as the source. Also prints suggested Portal checks (Key Vault Secrets blade, IAM role
  assignments, AKS add-on status).
