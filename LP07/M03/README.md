# LP07 / M03 — Build serverless AI backends with Azure Functions

**Labs:**
- [03-azure-functions-mcp-server.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/03-azure-functions-mcp-server.md)
- [04-durable-functions-ai.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/04-durable-functions-ai.md)

## Learning objectives (from the deck)
- Evaluate cold start/scaling/memory trade-offs: Flex Consumption vs. Premium
- Set up local dev with Core Tools, emulators, and an IDE
- Create triggers/bindings for AI patterns (HTTP inference, queue batch processors)
- Configure Key Vault references and App Configuration for secrets
- Apply managed identity and function-level authorization

## Contents

- `demo/scripts/01-create-function-app` (bash/ps1) — Slide 30: Flex Consumption plan, storage account
- `demo/function-app/function_app.py` — Slide 32-33: HTTP trigger (`/classify`) + Service Bus trigger with blob output binding
- `demo/function-app/host.json`, `requirements.txt` — Python v2 programming model project files
- Lab 04 (Durable Functions): see [links.md](./links.md) for the orchestration pattern used for long-running AI pipelines beyond the 230s HTTP timeout

## Run it (local)

```bash
cd demo/function-app
pip install -r requirements.txt
func start
```

## Run it (deploy)

```bash
cd demo/scripts && ./01-create-function-app.sh   # or .ps1
func azure functionapp publish <app-name>
```
