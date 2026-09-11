# LP06 / M01 — Implement data operations in Azure Managed Redis

**Lab:** [01-amr-data-operations.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/01-amr-data-operations.md)

## Learning objectives (from the deck)
- Explain Azure Managed Redis capabilities and caching strategies
- Select client libraries and apply development best practices
- Implement storage, retrieval, expiration, and cache invalidation patterns

## Contents

- `demo/scripts/01-create-redis-cache` (bash/ps1) — Slide 6: Balanced tier, port 10000
- `demo/python/data_operations.py` — Slide 7-9: all core data types (strings, hashes, lists, sets, sorted sets, atomic INCR/DECR counters), pipelining, manual invalidation (explicit `DEL`), time-based invalidation (`SETEX`/TTL - waits for a real expiry to happen, not just printing the configured value), cache-aside, and key iteration (`SCAN` vs `KEYS`, with a comment on why `KEYS` is unsafe in production despite matching here on a tiny local dataset)

Verified against a real 3-node Redis Cluster (`redis-server --cluster-enabled yes`,
formed with `redis-cli --cluster create`), not just a single local instance - a
single node has no slot sharding and structurally can't catch Redis Cluster
cross-slot errors, which is exactly the category of bug that slipped through
initial single-node testing and surfaced on real Azure Managed Redis instead. Two
were fixed as a result: `r.pipeline()` defaults to a `MULTI`/`EXEC` transaction,
which requires every key touched to share a slot (fixed with `transaction=False` -
a non-transactional pipeline just batches independent commands, no shared-slot
requirement); and the multi-key forms of `DEL`/`MSET` are genuine server-side
atomic operations with the same same-slot requirement and no equivalent
workaround, so those became one call per key instead. Re-testing against the real
cluster also surfaced a second, more subtle issue: `KEYS` only returns matches
from whichever single shard it happens to hit, silently missing the rest -
confirmed finding 1 of 4 keys where `scan_iter()` correctly found all 4 - so the
demo's `KEYS` vs `SCAN` comparison now reports actual counts from whatever
environment it's run against instead of asserting they'll match.

## Run it

```bash
cd demo/scripts && ./01-create-redis-cache.sh   # or .ps1
cd ../python && pip install redis && python data_operations.py
```
