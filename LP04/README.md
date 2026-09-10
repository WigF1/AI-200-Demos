# LP04 — Develop AI solutions with Azure Cosmos DB for NoSQL

Source deck: `AI-200T00A-ENU-PowerPoint_04.pptx`

| Module | Topic | Lab |
|---|---|---|
| [M01](./M01) | Build queries for Azure Cosmos DB for NoSQL | [01-build-rag-document-store.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/01-build-rag-document-store.md) |
| [M02](./M02) | Implement vector search with Azure Cosmos DB for NoSQL | [02-build-semantic-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/02-build-semantic-search.md) |
| [M03](./M03) | Optimize query performance for Azure Cosmos DB for NoSQL | [03-optimize-query-performance.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/03-optimize-query-performance.md) |

Each module has `demo/scripts` (bash + PowerShell provisioning via `az cosmosdb`)
and `demo/python` (SDK scripts using `azure-cosmos` for the actual data/query work —
Python is cross-platform so one script serves both shells). Each module is
self-contained - `00-ensure-prereqs` (M02/M03) bootstraps the account/database/base
container if M01 hasn't run.

## M02: vector search needs a one-time account capability, which can take up to 15 minutes

`EnableNoSQLVectorSearch` must be enabled on the account before creating a
vector-policy container. Confirmed against Microsoft's own docs: the request is
auto-approved but "might take 15 minutes to take effect." `01-create-vector-container`
handles this automatically - it enables the capability if needed, then retries
container creation every 30s for up to ~16 minutes rather than making you re-run
the script by hand. First run may genuinely take a while; that's expected, not stuck.
