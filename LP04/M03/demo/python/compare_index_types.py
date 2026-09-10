"""
LP04 / M03 - Compare flat, quantizedFlat, and diskANN vector index
performance in Azure Cosmos DB for NoSQL

Demonstrates (mapped to deck slides):
  - Slide 30: index type selection depends on dataset size - quantizedFlat
    and diskANN don't even activate below 1,000 vectors (falls back to a
    brute-force scan, same as flat) - this script seeds enough data to
    clear that threshold so the comparison actually measures something.
  - Slide 30: flat is exact/simplest but capped at 505 dimensions;
    quantizedFlat and diskANN scale further and are approximate.

Runs against a real Azure Cosmos DB account (see 02-create-index-
comparison-containers.sh/.ps1). At this data volume the whole exercise
- creating the account, seeding ~3,600 items across three containers, and
running the comparison queries - costs a few cents on serverless pricing
($0.25 per million RUs), so there's no need to reach for the local
emulator here.

Requires:
  pip install azure-cosmos
  export COSMOS_ENDPOINT=... COSMOS_KEY=...
Run 02-create-index-comparison-containers first.
"""
import os
import random
import time

from azure.cosmos import CosmosClient

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY = os.environ["COSMOS_KEY"]
DATABASE_NAME = "ragstore"
DIMENSIONS = 384  # must match the vector policy in 02-create-index-comparison-containers
ITEM_COUNT = 1200  # clears the 1,000-vector activation threshold with some margin
CATEGORIES = ["networking", "hardware", "software", "security", "cloud"]

CONTAINERS = {
    "flat": "idx_flat",
    "quantizedFlat": "idx_quantizedflat",
    "diskANN": "idx_diskann",
}

client = CosmosClient(ENDPOINT, credential=KEY)
database = client.get_database_client(DATABASE_NAME)


def fake_embedding(seed: int) -> list[float]:
    """Stand-in for a real embedding model call - deterministic per seed,
    so the SAME item gets the SAME vector in all three containers."""
    rnd = random.Random(seed)
    return [rnd.uniform(-1, 1) for _ in range(DIMENSIONS)]


def seed_container(index_type: str, container_name: str):
    container = database.get_container_client(container_name)
    existing = list(container.query_items(
        query="SELECT VALUE COUNT(1) FROM c", enable_cross_partition_query=True,
    ))
    if existing and existing[0] >= ITEM_COUNT:
        print(f"[{index_type}] already has {existing[0]} items - skipping seed")
        return

    print(f"[{index_type}] seeding {ITEM_COUNT} items into '{container_name}'...")
    start = time.time()
    for i in range(ITEM_COUNT):
        container.upsert_item({
            "id": f"item-{i}",
            "category": CATEGORIES[i % len(CATEGORIES)],
            "title": f"Sample document {i}",
            "embedding": fake_embedding(i),
        })
        if (i + 1) % 200 == 0:
            print(f"  ...{i + 1}/{ITEM_COUNT}")
    print(f"[{index_type}] seeded in {time.time() - start:.1f}s")


def query_and_measure(index_type: str, container_name: str) -> dict:
    container = database.get_container_client(container_name)
    query_vector = fake_embedding(0)  # pretend this is the user's query embedding

    start = time.time()
    results = list(container.query_items(
        query="""
            SELECT TOP 10 c.title, VectorDistance(c.embedding, @queryVector) AS Score
            FROM c
            ORDER BY VectorDistance(c.embedding, @queryVector)
        """,
        parameters=[{"name": "@queryVector", "value": query_vector}],
        enable_cross_partition_query=True,
    ))
    elapsed_ms = (time.time() - start) * 1000
    charge = container.client_connection.last_response_headers.get(
        "x-ms-request-charge", "n/a"
    )
    return {"index_type": index_type, "results": len(results), "ms": elapsed_ms, "ru": charge}


if __name__ == "__main__":
    for index_type, container_name in CONTAINERS.items():
        seed_container(index_type, container_name)

    print("\nRunning the same TOP 10 vector query against all three containers...\n")
    rows = [query_and_measure(index_type, container_name) for index_type, container_name in CONTAINERS.items()]

    print(f"{'Index type':<15} {'Results':<10} {'Latency (ms)':<15} {'RU charge':<10}")
    for row in rows:
        print(f"{row['index_type']:<15} {row['results']:<10} {row['ms']:<15.1f} {row['ru']:<10}")

    print(
        "\nExpect flat to be exact but scan-like as data grows; quantizedFlat and "
        "diskANN should show lower RU charge and/or latency at this scale, with "
        "diskANN typically the strongest fit for larger production datasets "
        "(Slide 30)."
    )
