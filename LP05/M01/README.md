# LP05 / M01 — Build and query with Azure Database for PostgreSQL

**Lab:** [01-build-agent-tool-backend.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-database-postgresql/01-build-agent-tool-backend.md)

## Learning objectives (from the deck)
- Explain the architecture and key features of Azure Database for PostgreSQL
- Establish secure connections using Microsoft Entra authentication and TLS
- Create and manage database schemas (tables, indexes, constraints)
- Write efficient SQL queries for common data operations
- Integrate PostgreSQL into applications using Python

## Contents

- `demo/scripts/01-create-postgres-server` (bash/ps1) — Slide 6-7: Burstable tier, firewall rule, Entra admin
- `demo/python/schema_and_queries.py` — Slide 8-10: JSONB schema, upsert with `ON CONFLICT`, keyset pagination, `ConnectionPool`

## Run it

```bash
cd demo/scripts && ./01-create-postgres-server.sh   # or .ps1
cd ../python && pip install "psycopg[binary,pool]" && python schema_and_queries.py
```
