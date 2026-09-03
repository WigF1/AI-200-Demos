# LP02 / M03 — Scale containers in Azure Container Apps

**Lab:** [03-aca-scale-containers.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-container-apps/03-aca-scale-containers.md)

## Learning objectives (from the deck)
- Configure HTTP, TCP, CPU, and memory scale rules
- Implement event-driven scaling using KEDA scalers
- Select appropriate compute resources for performance and cost
- Apply revision modes to control scaling behavior and traffic distribution

## Demo scripts

| Script | Slide touch point |
|---|---|
| `01-http-scale-rule` | Slide 30: HTTP concurrency-based scale rule, min/max replicas |
| `02-keda-servicebus-scaler` | Slide 31: KEDA Azure Service Bus scaler, scale-to-zero |
| `03-traffic-split-revisions` | Slide 34: multiple revision mode, weighted traffic split (canary/blue-green) |

Requires LP02/M01 (environment + app) and, for script 02, a Service Bus
queue (see [LP07/M01](../../LP07/M01) if you want a pre-provisioned one).
