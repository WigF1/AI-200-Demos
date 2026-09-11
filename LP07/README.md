# LP07 — Integrate Backend Services for AI Solutions

Source deck: `AI-200T00A-ENU-PowerPoint_07.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Queue and process AI operations with Azure Service Bus | [01-svcbus-process-messages.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/01-svcbus-process-messages.md) |
| [M02](./M02) | Develop event-driven AI workflows with Azure Event Grid | [02-eventgrid-publish-receive-events.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/02-eventgrid-publish-receive-events.md) |
| [M03](./M03) | Build serverless AI backends with Azure Functions | [03-azure-functions-mcp-server.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/03-azure-functions-mcp-server.md), [04-durable-functions-ai.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/04-durable-functions-ai.md) |

Each module has `demo/scripts` (bash + PowerShell provisioning) and
`demo/python` (SDK / Functions code for the actual messaging & compute work).
Unlike LP04-06, each module here provisions a fully independent resource
type (Service Bus, Event Grid, Functions) rather than sharing one
resource across modules, so there's no cross-module bootstrap needed -
just per-module idempotent creation and `99-cleanup.sh`/`.ps1`.

## M03: queries the current Flex Consumption Python version dynamically

Confirmed against Microsoft's own docs that supported Flex Consumption
runtime versions vary by region and change over time - their own
"how-to" doc's prose (explicitly listing only Python 3.10/3.11) lags
behind what `az functionapp list-flexconsumption-runtimes` actually
returns as currently supported (3.12 and 3.13 in some regions). Rather
than hardcode a version that could quietly stop being supported,
`01-create-function-app` queries the runtime list directly and uses the
highest version returned.

## Verification notes

Unlike LP04-06 (Cosmos DB, PostgreSQL, Redis), none of Service Bus,
Event Grid, or Azure Functions have a local OSS binary this sandbox can
install and test against, so none of LP07 could be verified by actually
running it end-to-end. Verified instead through careful documentation
cross-checking (multiple independent, current sources per claim) and
close comparison against the deck's own code snippets, which the SDK
usage here matches closely.
