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

- `demo/scripts/local-dev-setup` (bash/ps1) — Slide 31: `document-jobs` queue, Service Bus Data Receiver role for you, `local.settings.json`
- `demo/scripts/01-create-function-app` (bash/ps1) — Slide 30: Flex Consumption plan, storage account
- `demo/function-app/function_app.py` — Slide 32-33: HTTP trigger (`/classify`) + Service Bus trigger with blob output binding
- `demo/function-app/host.json`, `requirements.txt` — Python v2 programming model project files
- Lab 04 (Durable Functions): see [links.md](./links.md) for the orchestration pattern used for long-running AI pipelines beyond the 230s HTTP timeout

## Run it (local)

Prerequisite: the LP07/M01 Service Bus namespace (`LP07/M01/demo/scripts/01-create-servicebus`). The Service Bus trigger listens on its `document-jobs` queue.

```bash
cd demo/scripts && ./local-dev-setup.sh          # or .ps1 - queue, your RBAC role, local.settings.json

# In a second terminal: Azurite, the local storage emulator that
# AzureWebJobsStorage=UseDevelopmentStorage=true points at (host locks + the blob output binding)
npx azurite --location ~/.azurite --silent

cd ../function-app
pip install -r requirements.txt
func start
```

Why the setup script matters:
- **`local.settings.json`** is gitignored, so a fresh clone doesn't have one. Without it, `func start` fails with *"Can't determine project language"*. `func start --python` then generates an encrypted stub with only the worker runtime, and the host fails with *"Secret initialization from Blob storage failed"* because there's no `AzureWebJobsStorage`. The script replaces that stub; it doesn't touch a file you've edited.
- **The Service Bus trigger connects identity-based** (`ServiceBusConnection__fullyQualifiedNamespace`), which locally means your `az login` account. Owner doesn't include data-plane access, so the script grants *Azure Service Bus Data Receiver*. A new role assignment can take a few minutes to apply.

Try it:

```bash
curl -X POST http://localhost:7071/api/classify -H "Content-Type: application/json" -d '{"text":"hello world"}'
# Send {"document_url": "https://example.com/contract-1.pdf"} to the document-jobs queue (Service Bus Explorer in the portal works),
# then see the result blob in Azurite:
curl -X POST http://localhost:7071/admin/functions/process_and_store \
  -H "Content-Type: application/json" \
  -d '{"input": "{\"document_url\": \"https://example.com/contract-1.pdf\"}"}'
az storage blob list --connection-string "UseDevelopmentStorage=true" -c results -o table
```

Locally, `/api/classify` needs no function key. Function-level auth only applies once deployed.

## Run it (deploy)

Prerequisite: the LP07/M01 Service Bus namespace, as for the local run.

```bash
cd demo/scripts && ./01-create-function-app.sh   # or .ps1
cd ../function-app && func azure functionapp publish func-<suffix>
```

Besides the app itself, `01-create-function-app` wires up the Service Bus trigger's identity-based connection: the `document-jobs` queue, *Azure Service Bus Data Receiver* for the app's managed identity, and the `ServiceBusConnection__fullyQualifiedNamespace` app setting. Without those the app deploys fine, but the trigger never fires.

Try it:

```bash
KEY=$(az functionapp function keys list -g rg-ai200-lp07-integrate -n func-<suffix> --function-name classify_document --query default -o tsv)
curl -X POST https://func-<suffix>.azurewebsites.net/api/classify -H "x-functions-key: $KEY" -H "Content-Type: application/json" -d '{"text":"hello world"}'
# without the key: 401 (function-level auth, Slide 35)
```

Teardown: `99-cleanup` removes the app, its storage account, the `document-jobs` queue, and the app identity's role assignment.
