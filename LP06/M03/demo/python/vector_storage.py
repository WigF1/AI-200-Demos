"""
LP06 / M03 - Implement vector storage in Azure Managed Redis

Demonstrates (mapped to deck slides):
  - Slide 27: create a vector index (HNSW, COSINE, FLOAT32, 1536 dims) over
    Hash-stored documents
  - Slide 27: bulk ingestion via pipeline, embeddings converted with tobytes()
  - Slide 28: KNN query pattern

Requires:
  pip install redis numpy
  export REDIS_HOST=... REDIS_KEY=...
"""
import os
import random

import numpy as np
import redis
from redis.commands.search.field import TextField, VectorField
from redis.commands.search.indexDefinition import IndexDefinition, IndexType
from redis.commands.search.query import Query

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=False,  # binary-safe for vector bytes
)

INDEX_NAME = "idx:docs"
KEY_PREFIX = "doc:"
DIMENSIONS = 1536


def fake_embedding(seed: int) -> np.ndarray:
    rnd = np.random.RandomState(seed)
    return rnd.uniform(-1, 1, DIMENSIONS).astype(np.float32)


def create_index():
    try:
        r.ft(INDEX_NAME).info()
        print(f"Index '{INDEX_NAME}' already exists")
        return
    except redis.exceptions.ResponseError:
        pass  # doesn't exist yet, create it

    schema = (
        TextField("title"),
        TextField("category"),
        VectorField(
            "embedding",
            "HNSW",
            {"TYPE": "FLOAT32", "DIM": DIMENSIONS, "DISTANCE_METRIC": "COSINE"},
        ),
    )
    r.ft(INDEX_NAME).create_index(
        fields=schema,
        definition=IndexDefinition(prefix=[KEY_PREFIX], index_type=IndexType.HASH),
    )
    print(f"Created index '{INDEX_NAME}' (HNSW, cosine, {DIMENSIONS} dims)")


def ingest_documents():
    docs = [
        {"id": "1", "title": "WiFi troubleshooting", "category": "networking"},
        {"id": "2", "title": "VPN setup guide", "category": "networking"},
        {"id": "3", "title": "Bluetooth speaker manual", "category": "electronics"},
    ]
    pipe = r.pipeline()
    for i, doc in enumerate(docs):
        key = f"{KEY_PREFIX}{doc['id']}"
        embedding_bytes = fake_embedding(i).tobytes()
        pipe.hset(key, mapping={
            "title": doc["title"],
            "category": doc["category"],
            "embedding": embedding_bytes,
        })
    pipe.execute()
    print(f"Ingested {len(docs)} documents via pipeline")


def knn_query():
    # Slide 28: KNN - fixed count of nearest neighbors.
    query_vector = fake_embedding(0).tobytes()
    query = (
        Query("*=>[KNN 3 @embedding $vec AS score]")
        .sort_by("score")
        .return_fields("title", "category", "score")
        .dialect(2)
    )
    results = r.ft(INDEX_NAME).search(query, query_params={"vec": query_vector})
    print("KNN results:")
    for doc in results.docs:
        print(f"  {doc.title} ({doc.category}) - score={doc.score}")


def hybrid_query():
    # Slide 28: Hybrid - metadata filter + vector similarity.
    query_vector = fake_embedding(0).tobytes()
    query = (
        Query("@category:networking=>[KNN 2 @embedding $vec AS score]")
        .sort_by("score")
        .return_fields("title", "score")
        .dialect(2)
    )
    results = r.ft(INDEX_NAME).search(query, query_params={"vec": query_vector})
    print("Hybrid results (category=networking):")
    for doc in results.docs:
        print(f"  {doc.title} - score={doc.score}")


if __name__ == "__main__":
    create_index()
    ingest_documents()
    knn_query()
    hybrid_query()
