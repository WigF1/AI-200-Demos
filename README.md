# AI-200 Demos

Demo scripts, Microsoft Learn reference links, and Kubernetes/Function
project files supporting the **AI-200T00A** course deck set and its
associated hands-on labs from
[MicrosoftLearning/mslearn-azure-ai](https://github.com/MicrosoftLearning/mslearn-azure-ai).

## Layout

Each learning path (matching one PowerPoint deck) gets its own top-level
folder, numbered by position. Inside, each module gets its own folder,
numbered to match the deck's module numbering:

```
LP01/                  Deck 1: Implement container application hosting on Azure
  M01/                 Module 1: Store and manage containers in ACR
    README.md          Learning objectives + what's in this folder
    links.md            Microsoft Learn reference table for this module
    demo/
      scripts/          az CLI provisioning: *.sh (bash) and *.ps1 (PowerShell), 1:1
      python/           SDK demo scripts, where the module needs real data/query work
      manifests/         Kubernetes YAML, where relevant (AKS learning path)
  M02/
    ...
LP02/ ... LP09/         Same pattern for the remaining 8 decks
shared/inference-api/    One small Flask app reused as the deploy target
                         across LP01 (App Service), LP02 (Container Apps),
                         and LP03 (AKS) - same code, three compute platforms
```

## Learning paths

| Folder | Deck | Modules |
|---|---|---|
| [LP01](./LP01) | Implement container application hosting on Azure | ACR, App Service (+ sidecars) |
| [LP02](./LP02) | Deploy and manage apps on Azure Container Apps | Deploy, Manage, Scale |
| [LP03](./LP03) | Deploy and monitor apps on Azure Kubernetes Service | Deploy, Configure, Monitor/troubleshoot |
| [LP04](./LP04) | Develop AI solutions with Azure Cosmos DB for NoSQL | Queries, Vector search, Optimize |
| [LP05](./LP05) | Develop AI solutions with Azure Database for PostgreSQL | Build/query, pgvector, Optimize |
| [LP06](./LP06) | Enhance AI solutions with Azure Managed Redis | Data ops, Pub/sub + Streams, Vector storage |
| [LP07](./LP07) | Integrate Backend Services for AI Solutions | Service Bus, Event Grid, Azure Functions |
| [LP08](./LP08) | Manage application secrets and configuration for AI solutions | Key Vault, App Configuration |
| [LP09](./LP09) | Observe and troubleshoot apps on Azure | OpenTelemetry, KQL |

## Running a demo

Every `demo/scripts` folder has matching bash (`.sh`) and PowerShell
(`.ps1`) versions of the same provisioning steps — pick whichever matches
your terminal. Scripts read a `SUFFIX` (and sometimes other) environment
variable/parameter for uniquely naming resources; set it before running:

```bash
# bash
export SUFFIX=myinitials01
cd LP01/M01/demo/scripts
./01-create-acr.sh
```

```powershell
# PowerShell
$Suffix = "myinitials01"
cd LP01/M01/demo/scripts
./01-create-acr.ps1
```

Where a module needs actual data/query/messaging work (Cosmos DB,
PostgreSQL, Redis, Service Bus, Event Grid, Functions, Key Vault, App
Configuration, OpenTelemetry), the `demo/python` folder has the SDK code —
Python is cross-platform, so one script serves both shells. Each script's
docstring/comments cite the exact deck slide it demonstrates.

## Prerequisites

- Azure CLI (`az`), signed in (`az login`)
- Azure PowerShell (`Az` module) if using the `.ps1` scripts
- Python 3.10+ for the SDK demos
- `kubectl` for LP03 (AKS)
- Azure Functions Core Tools (`func`) for LP07/M03
- Docker (optional, for local testing of the shared inference-api image)

## Source labs

The lab instructions referenced throughout this repo live in
[MicrosoftLearning/mslearn-azure-ai](https://github.com/MicrosoftLearning/mslearn-azure-ai/tree/main/instructions).
Each module's README links directly to its corresponding lab file.
