# LP04 / M01 — Build queries for Azure Cosmos DB for NoSQL

**Lab:** [01-build-rag-document-store.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/01-build-rag-document-store.md)

## Learning objectives (from the deck)
- Explain the resource model: databases, containers, items
- Implement SDK operations for CRUD on items
- Select between point reads and queries based on access patterns
- Build SQL-syntax queries to filter, project, retrieve data

## Contents

- `demo/scripts/01-create-cosmos-account` (bash/ps1) — Slide 6: account, database, container, partition key
- `demo/python/crud_and_queries.py` — Slide 7-9: singleton client, point read vs. query, parameterized + single-partition vs. cross-partition queries

## Run it

```bash
cd demo/scripts && ./01-create-cosmos-account.sh      # or .ps1
cd ../python && pip install azure-cosmos && python crud_and_queries.py
```
