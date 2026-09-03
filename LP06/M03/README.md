# LP06 / M03 — Implement vector storage in Azure Managed Redis

**Lab:** [03-amr-vector-storage.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/03-amr-vector-storage.md)

## Learning objectives (from the deck)
- Create vector indexes and query embeddings using Redis as a vector database
- Choose vector types, distance metrics, indexing algorithms (FLAT/HNSW)
- Select Hash vs. JSON storage for vectors + metadata
- Build Python apps that index and query embeddings

## Contents

- `demo/python/vector_storage.py` — Slide 27-28: `VectorField` schema, `tobytes()` ingestion, KNN/hybrid/range queries

No new resource needed — reuses the cache from LP06/M01 (RediSearch is
built into Azure Managed Redis).

## Run it

```bash
pip install redis numpy
python vector_storage.py
```
