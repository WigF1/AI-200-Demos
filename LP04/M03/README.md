# LP04 / M03 — Optimize query performance for Azure Cosmos DB for NoSQL

**Lab:** [03-optimize-query-performance.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/cosmosdb/03-optimize-query-performance.md)

## Learning objectives (from the deck)
- Analyze query patterns/metrics to find bottlenecks and missing indexes
- Configure range and composite indexes for AI retrieval patterns
- Select the right vector index type for dataset size/accuracy needs
- Design indexing policies balancing read performance vs. write cost
- Choose consistency levels that minimize RU while meeting requirements

## Contents

- `demo/scripts/01-apply-indexing-policy` (bash/ps1) — Slide 29, 31: selective indexing + composite index for a filter+sort pattern
- `demo/python/query_metrics.py` — Slide 31: read `x-ms-request-charge` / query metrics to spot missing indexes
- `demo/scripts/02-create-index-comparison-containers` (bash/ps1) — Slide 30: creates three containers (`idx_flat`, `idx_quantizedflat`, `idx_diskann`), identical vector policies except index type. Vector policies are immutable after creation, which is why this needs three containers rather than reconfiguring one.
- `demo/python/compare_index_types.py` — seeds 1,200 identical items into each container (clears the 1,000-vector threshold below which quantizedFlat/diskANN don't activate and silently fall back to brute-force scan), then runs the same `TOP 10` vector query against all three and reports latency + RU charge side by side. Uses 384 dimensions, not 1536 - `flat` caps out at 505 dimensions, so all three need to share a dimension count under that limit for a fair, working comparison.

## Run it

```bash
cd demo/scripts && ./01-apply-indexing-policy.sh   # or .ps1
cd ../python && pip install azure-cosmos && python query_metrics.py

cd ../scripts && ./02-create-index-comparison-containers.sh   # or .ps1
cd ../python && python compare_index_types.py
```

Cost note: seeding ~3,600 items across the three containers plus the comparison
queries costs a few cents on Cosmos DB serverless pricing ($0.25 per million RUs) -
cheap enough that this is built to run directly against Azure rather than a local
emulator.
