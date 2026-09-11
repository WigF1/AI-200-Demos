# LP06 / M01 — Implement data operations in Azure Managed Redis

**Lab:** [01-amr-data-operations.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/01-amr-data-operations.md)

## Learning objectives (from the deck)
- Explain Azure Managed Redis capabilities and caching strategies
- Select client libraries and apply development best practices
- Implement storage, retrieval, expiration, and cache invalidation patterns

## Contents

- `demo/scripts/01-create-redis-cache` (bash/ps1) — Slide 6: Balanced tier, port 10000
- `demo/python/data_operations.py` — Slide 7-9: all core data types (strings, hashes, lists, sets, sorted sets, atomic INCR/DECR counters), pipelining, manual invalidation (explicit `DEL`), time-based invalidation (`SETEX`/TTL - waits for a real expiry to happen, not just printing the configured value), cache-aside, and key iteration (`SCAN` vs `KEYS`, with a comment on why `KEYS` is unsafe in production despite matching here on a tiny local dataset)

Verified by running the actual script against a local `redis-server` before shipping,
which confirmed every command's individual correctness - but a single-node local
instance has no slot sharding, so it structurally can't catch Redis Cluster
cross-slot errors. Two surfaced on real Azure Managed Redis testing and are now
fixed: `r.pipeline()` defaults to a `MULTI`/`EXEC` transaction, which requires
every key touched to share a slot (fixed with `transaction=False` - a
non-transactional pipeline just batches independent commands, no shared-slot
requirement); and the multi-key forms of `DEL`/`MSET` are genuine server-side
atomic operations with the same same-slot requirement and no equivalent
workaround, so those became one call per key instead.

## Run it

```bash
cd demo/scripts && ./01-create-redis-cache.sh   # or .ps1
cd ../python && pip install redis && python data_operations.py
```
