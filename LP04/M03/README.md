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

## Run it

```bash
cd demo/scripts && ./01-apply-indexing-policy.sh   # or .ps1
cd ../python && pip install azure-cosmos && python query_metrics.py
```
