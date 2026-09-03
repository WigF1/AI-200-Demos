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
- `demo/python/pgvector_search.py` — Slide 18-22: `vector(n)` column, distance operators, IVFFlat/HNSW index, RAG chunk retrieval

## Run it

```bash
cd demo/scripts && ./01-enable-pgvector.sh   # or .ps1
cd ../python && pip install "psycopg[binary,pool]" pgvector && python pgvector_search.py
```
