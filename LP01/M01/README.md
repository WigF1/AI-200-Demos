# LP01 / M01 — Store and manage containers in Azure Container Registry

**Lab:** [01-acr-tasks.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/container-hosting/01-acr-tasks.md)

## Learning objectives (from the deck)
- Explain how ACR organizes images using registries, repositories, and artifacts
- Build and manage container images in the cloud using ACR Tasks
- Implement tagging and versioning strategies for reliable deployments
- Use the Azure CLI to manage container images and run ACR quick tasks

## Demo scripts

Run from `demo/scripts/`. Bash (`.sh`) and PowerShell (`.ps1`) versions are
functionally identical — pick whichever matches your terminal.

| Script | Slide touch point |
|---|---|
| `01-create-acr` | Slide 5: managed private registry, service tiers |
| `02-build-push-acr-task` | Slide 7: ACR Tasks quick build (cloud build, no local Docker) |
| `03-tag-version-lock` | Slide 6 & 8: tags vs. immutable digests, image locking |
| `04-cleanup-untagged` | Slide 8: scheduled purge of untagged images |

See [`links.md`](./links.md) for the full Microsoft Learn reference list.

## Run it

```bash
cd demo/scripts
./01-create-acr.sh          # or .ps1
./02-build-push-acr-task.sh
./03-tag-version-lock.sh
./04-cleanup-untagged.sh
```
