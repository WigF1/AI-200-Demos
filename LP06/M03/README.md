# LP06 / M03 — Implement vector storage in Azure Managed Redis

**Lab:** [03-amr-vector-storage.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/03-amr-vector-storage.md)

## Learning objectives (from the deck)
- Create vector indexes and query embeddings using Redis as a vector database
- Choose vector types, distance metrics, indexing algorithms (FLAT/HNSW)
- Select Hash vs. JSON storage for vectors + metadata
- Build Python apps that index and query embeddings

## Contents

- `demo/python/vector_storage.py` — Slide 27-28: `VectorField` schema, `tobytes()` bulk ingestion, KNN and hybrid (metadata filter + vector) queries. Slide 33: real FLAT vs HNSW comparison - seeds 2,000 vectors under each algorithm's own key prefix (so both get independent indexes over identical data) and times index build + average KNN query for each side by side.

**Verification note:** unlike M01/M02, this could only be partially tested locally - the RediSearch module available via apt for local testing predates vector field support entirely. Schema and query syntax were verified against current documentation from multiple independent sources instead. One real bug was still caught this way: `redis.commands.search.indexDefinition` (shown in some current-looking docs) doesn't exist in the `redis` package version `pip install redis` currently installs - confirmed by direct testing against the actual installed package - the correct module is `index_definition`. The bulk-seeding pipeline pattern itself (`transaction=False` across many different keys) *was* verified against a real 3-node Redis Cluster - confirmed seeding 2,000 keys across multiple slots without a cross-slot error, the same class of bug M01 hit and fixed.

No new resource needed — reuses the cache from LP06/M01 (RediSearch is
built into Azure Managed Redis).

## Run it

```bash
pip install redis numpy
python vector_storage.py
```
