"""
LP06 / M03 - Implement vector storage in Azure Managed Redis

Demonstrates (mapped to deck slides):
  - Slide 27: vector index schema (HNSW/FLAT, COSINE, FLOAT32, dims) over
    Hash-stored documents
  - Slide 27: bulk ingestion via pipeline, embeddings converted with
    tobytes()
  - Slide 28: KNN and hybrid (metadata filter + vector) query patterns
  - Slide 33: FLAT vs HNSW - real seeded data, side-by-side query timing,
    not just "here's how you create each one." Deck guidance: FLAT under
    10,000 vectors, HNSW beyond that - this seeds enough data to be
    meaningful while staying quick to run on a Balanced_B1 cache.
  - Slide 29: Hash vs JSON storage - this demo uses Hash throughout
    (deck's own guidance: "Hash for flat data and performance"); JSON
    storage is the alternative when you need nested structures or
    multiple vectors per document, at some memory/performance cost.

Requires:
  pip install redis numpy
  export REDIS_HOST=... REDIS_KEY=...
"""
import os
import time

import numpy as np
import redis
from redis.commands.search.field import TagField, VectorField
from redis.commands.search.index_definition import IndexDefinition, IndexType
from redis.commands.search.query import Query

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=False,  # binary-safe for vector bytes
)

DIMENSIONS = 1536
BULK_ROW_COUNT = 2000  # comfortably exercises FLAT and gives HNSW something to do
CATEGORIES = ["networking", "hardware", "software", "security", "cloud"]


def fake_embedding(seed: int) -> np.ndarray:
    rnd = np.random.RandomState(seed)
    return rnd.uniform(-1, 1, DIMENSIONS).astype(np.float32)


def create_index(index_name: str, key_prefix: str, algorithm: str):
    try:
        r.ft(index_name).info()
        print(f"Index '{index_name}' already exists")
        return
    except redis.exceptions.ResponseError:
        pass  # doesn't exist yet, create it

    if algorithm == "FLAT":
        vector_params = {"TYPE": "FLOAT32", "DIM": DIMENSIONS, "DISTANCE_METRIC": "COSINE"}
    else:  # HNSW
        vector_params = {
            "TYPE": "FLOAT32", "DIM": DIMENSIONS, "DISTANCE_METRIC": "COSINE",
            "M": 16, "EF_CONSTRUCTION": 200,
        }

    schema = (
        TagField("category"),
        VectorField("embedding", algorithm, vector_params),
    )
    r.ft(index_name).create_index(
        fields=schema,
        definition=IndexDefinition(prefix=[key_prefix], index_type=IndexType.HASH),
    )
    print(f"Created index '{index_name}' ({algorithm}, cosine, {DIMENSIONS} dims, prefix '{key_prefix}')")


def seed_bulk_vectors(key_prefix: str):
    # Same seeds/categories used for both prefixes, so FLAT and HNSW are
    # compared on identical data - only the index algorithm differs.
    print(f"Seeding {BULK_ROW_COUNT} documents under prefix '{key_prefix}'...")
    start = time.perf_counter()
    pipe = r.pipeline(transaction=False)
    for i in range(BULK_ROW_COUNT):
        key = f"{key_prefix}{i}"
        pipe.hset(key, mapping={
            "category": CATEGORIES[i % len(CATEGORIES)],
            "embedding": fake_embedding(i).tobytes(),
        })
        if (i + 1) % 500 == 0:
            pipe.execute()
            pipe = r.pipeline(transaction=False)
    pipe.execute()
    print(f"Seeded in {time.perf_counter() - start:.1f}s")


def time_knn_query(index_name: str, repeats: int = 5) -> float:
    query_vector = fake_embedding(0).tobytes()
    query = Query("*=>[KNN 10 @embedding $vec AS score]").sort_by("score").dialect(2)
    times = []
    for _ in range(repeats):
        start = time.perf_counter()
        r.ft(index_name).search(query, query_params={"vec": query_vector})
        times.append(time.perf_counter() - start)
    return sum(times) / len(times)


def compare_flat_vs_hnsw():
    print("\n=== Seeding and indexing (FLAT) ===")
    seed_bulk_vectors("vec_flat:")
    flat_build_start = time.perf_counter()
    create_index("idx:vec_flat", "vec_flat:", "FLAT")
    flat_build_seconds = time.perf_counter() - flat_build_start
    flat_query_seconds = time_knn_query("idx:vec_flat")

    print("\n=== Seeding and indexing (HNSW) ===")
    seed_bulk_vectors("vec_hnsw:")
    hnsw_build_start = time.perf_counter()
    create_index("idx:vec_hnsw", "vec_hnsw:", "HNSW")
    hnsw_build_seconds = time.perf_counter() - hnsw_build_start
    hnsw_query_seconds = time_knn_query("idx:vec_hnsw")

    print(f"\n=== Summary ({BULK_ROW_COUNT} vectors per index, {DIMENSIONS} dimensions) ===")
    print(f"{'Index':<8} {'Index build (s)':<18} {'Avg KNN query (ms)':<20}")
    print(f"{'FLAT':<8} {flat_build_seconds:<18.2f} {flat_query_seconds * 1000:<20.2f}")
    print(f"{'HNSW':<8} {hnsw_build_seconds:<18.2f} {hnsw_query_seconds * 1000:<20.2f}")
    print(
        "\n(Slide 33: FLAT is exact/brute-force - simplest, no tuning, fine under 10,000\n"
        " vectors. HNSW is approximate but built for scale - the gap between them\n"
        " widens as BULK_ROW_COUNT grows well past what's used here. Below a few\n"
        " thousand vectors, RediSearch itself may fall back to a linear scan for HNSW\n"
        " too, similar in spirit to Cosmos DB's quantizedFlat/diskANN activation\n"
        " threshold in LP04 - the tradeoff is real, but only shows up at real scale.)"
    )


def hybrid_query_demo():
    # Slide 28: metadata filter (TAG) narrows candidates before the
    # vector distance calculation - cheaper than a pure KNN scan when
    # the filter is selective.
    query_vector = fake_embedding(0).tobytes()
    query = (
        Query("@category:{networking}=>[KNN 5 @embedding $vec AS score]")
        .sort_by("score")
        .return_fields("category", "score")
        .dialect(2)
    )
    results = r.ft("idx:vec_hnsw").search(query, query_params={"vec": query_vector})
    print("\nHybrid query results (category=networking, HNSW index):")
    for doc in results.docs:
        print(f"  {doc.id} ({doc.category.decode() if isinstance(doc.category, bytes) else doc.category}) - score={doc.score}")


if __name__ == "__main__":
    compare_flat_vs_hnsw()
    hybrid_query_demo()
