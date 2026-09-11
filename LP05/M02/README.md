# LP05 / M02 — Implement vector search with Azure Database for PostgreSQL

**Lab:** [02-implement-vector-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/02-implement-vector-search.md)

## Learning objectives (from the deck)
- Store and query vector embeddings using the `pgvector` extension
- Execute vector similarity search using different distance metrics
- Create and manage vector indexes (IVFFlat, HNSW)
- Implement embedding update/refresh strategies
- Build RAG retrieval patterns (chunks, citations, token budgets)

## Contents

- `demo/scripts/01-enable-pgvector` (bash/ps1) — Slide 17: allowlist + `CREATE EXTENSION vector`
- `demo/python/pgvector_search.py` — Slide 18-22: `vector(n)` column, distance operators, RAG chunk retrieval, and a real IVFFlat vs HNSW comparison: seeds 3,000 rows (`BULK_ROW_COUNT`, adjustable) into a dedicated table, builds each index in turn (dropping the other first, since PostgreSQL - unlike Cosmos DB - allows dropping/recreating indexes freely, so one table serves both tests), and times both build and query for each. Forces `enable_seqscan off` (scoped via `SET LOCAL`) while testing each index specifically - confirmed while building this that PostgreSQL's planner reasonably prefers a sequential scan over either index at this row count, which would otherwise silently make the comparison measure scan time instead of index time.

## Run it

```bash
cd demo/scripts && ./01-enable-pgvector.sh   # or .ps1
cd ../python && pip install "psycopg[binary,pool]" pgvector && python pgvector_search.py
```
