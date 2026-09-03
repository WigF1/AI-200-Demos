# LP06 / M01 — Implement data operations in Azure Managed Redis

**Lab:** [01-amr-data-operations.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/01-amr-data-operations.md)

## Learning objectives (from the deck)
- Explain Azure Managed Redis capabilities and caching strategies
- Select client libraries and apply development best practices
- Implement storage, retrieval, expiration, and cache invalidation patterns

## Contents

- `demo/scripts/01-create-redis-cache` (bash/ps1) — Slide 6: Balanced tier, port 10000
- `demo/python/data_operations.py` — Slide 7-9: pipelining, strings/hashes/lists, `SETEX`/`EXPIRE`, cache-aside

## Run it

```bash
cd demo/scripts && ./01-create-redis-cache.sh   # or .ps1
cd ../python && pip install redis && python data_operations.py
```
