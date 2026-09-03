# LP03 / M03 — Monitor and troubleshoot applications on Azure Kubernetes Service

**Lab:** [03-aks-troubleshoot-container.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-kubernetes-service/03-aks-troubleshoot-container.md)

## Learning objectives (from the deck)
- Explain key monitoring signals for AI workloads on AKS
- Use `kubectl` and Azure tools to inspect logs and metrics
- Troubleshoot Pod and Service issues affecting AI APIs/workers
- Verify Service and ingress connectivity paths
- Apply a structured deploy → monitor → debug workflow

## Demo scripts

| Script | Slide touch point |
|---|---|
| `01-monitor-logs-metrics` | Slide 26: `kubectl logs`, `kubectl top`, Container insights |
| `02-break-and-diagnose` | Slide 27, 30: force `CrashLoopBackOff`, describe + Events, fix |
| `03-verify-connectivity` | Slide 28: EndpointSlices, port-forward before external exposure |

Requires LP03/M01 + M02 already deployed.
