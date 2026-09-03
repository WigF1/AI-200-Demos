# LP04 / M02 — Implement vector search with Azure Cosmos DB for NoSQL

**Lab:** [02-build-semantic-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/02-build-semantic-search.md)

## Learning objectives (from the deck)
- Store/retrieve vector embeddings with a container vector policy
- Execute vector similarity queries using `VectorDistance`
- Combine vector search with metadata filters and full-text (hybrid/RRF)
- Implement change feed processing to refresh embeddings

## Contents

- `demo/scripts/01-create-vector-container` (bash/ps1) — Slide 17: vector policy (path/dataType/dimensions/distanceFunction)
- `demo/python/vector_search.py` — Slide 18-19: store embeddings, `VectorDistance` + `TOP N` query pattern, metadata pre-filtering, RRF hybrid search

## Run it

```bash
cd demo/scripts && ./01-create-vector-container.sh   # or .ps1
cd ../python && pip install azure-cosmos numpy && python vector_search.py
```
