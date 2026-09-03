# LP05 / M03 — Optimize vector search in Azure Database for PostgreSQL

**Lab:** [03-optimize-vector-search.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/03-optimize-vector-search.md)

## Learning objectives (from the deck)
- Tune PostgreSQL/pgvector parameters for latency and memory
- Select/configure the right vector index type for the workload
- Design data layouts for storage and metadata filtering performance
- Scale the server for high-volume vector workloads
- Implement connection pooling/session management

## Contents

- `demo/scripts/01-tune-server-parameters` (bash/ps1) — Slide 30: `shared_buffers`, `work_mem`, `random_page_cost`, read replicas
- `demo/python/explain_and_tune.py` — Slide 30, 32: `EXPLAIN ANALYZE`, `SET LOCAL` session tuning, B-tree pre-filter + vector search

## Run it

```bash
cd demo/scripts && ./01-tune-server-parameters.sh   # or .ps1
cd ../python && pip install "psycopg[binary,pool]" pgvector && python explain_and_tune.py
```
