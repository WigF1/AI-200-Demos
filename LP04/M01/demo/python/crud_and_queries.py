"""
LP04 / M01 - Build queries for Azure Cosmos DB for NoSQL

Demonstrates (mapped to deck slides):
  - Slide 7: singleton CosmosClient pattern
  - Slide 7: point read (read_item) vs. query (query_items) - cost/latency contrast
  - Slide 8: parameterized SQL queries, CONTAINS()
  - Slide 9: single-partition query (fast/cheap) vs. cross-partition (fans out)

Requires:
  pip install azure-cosmos
  export COSMOS_ENDPOINT=<from 01-create-cosmos-account>
  export COSMOS_KEY=<from 01-create-cosmos-account>
"""
import os
import time

from azure.cosmos import CosmosClient, PartitionKey, exceptions

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY = os.environ["COSMOS_KEY"]
DATABASE_NAME = "ragstore"
CONTAINER_NAME = "documents"

# Slide 7: singleton client pattern - create ONE CosmosClient for the app
# lifetime. It owns the connection pool and routing cache.
client = CosmosClient(ENDPOINT, credential=KEY)
database = client.create_database_if_not_exists(DATABASE_NAME)
container = database.create_container_if_not_exists(
    id=CONTAINER_NAME,
    partition_key=PartitionKey(path="/categoryId"),
)


def seed_sample_items():
    items = [
        {"id": "doc-1", "categoryId": "networking", "title": "WiFi troubleshooting", "price": 0},
        {"id": "doc-2", "categoryId": "networking", "title": "VPN setup guide", "price": 0},
        {"id": "doc-3", "categoryId": "electronics", "title": "Bluetooth Speaker Manual", "price": 49.99},
    ]
    for item in items:
        container.upsert_item(item)
    print(f"Seeded {len(items)} items")


def demo_point_read_vs_query():
    # Point read: ~1 RU, know id + partition key.
    start = time.time()
    item = container.read_item(item="doc-1", partition_key="networking")
    point_read_ms = (time.time() - start) * 1000
    print(f"Point read: {item['title']} ({point_read_ms:.1f} ms)")

    # Query: need to filter/search, costs more RUs.
    start = time.time()
    query = "SELECT * FROM products p WHERE CONTAINS(p.title, @term)"
    params = [{"name": "@term", "value": "WiFi"}]
    results = list(container.query_items(
        query=query, parameters=params,
        partition_key="networking",  # single-partition: routes to one partition
    ))
    query_ms = (time.time() - start) * 1000
    print(f"Query (single-partition): {len(results)} result(s) ({query_ms:.1f} ms)")


def demo_single_vs_cross_partition():
    # Single-partition (preferred): partition_key supplied, routes to one partition.
    single = list(container.query_items(
        query="SELECT * FROM c WHERE c.categoryId = @cat",
        parameters=[{"name": "@cat", "value": "networking"}],
        partition_key="networking",
    ))
    print(f"Single-partition query: {len(single)} item(s)")

    # Cross-partition (needed when the filter doesn't include the partition
    # key): fans out to all partitions, higher RU cost.
    cross = list(container.query_items(
        query="SELECT * FROM c WHERE c.price > @minPrice",
        parameters=[{"name": "@minPrice", "value": 10}],
        enable_cross_partition_query=True,
    ))
    print(f"Cross-partition query: {len(cross)} item(s)")


if __name__ == "__main__":
    seed_sample_items()
    demo_point_read_vs_query()
    demo_single_vs_cross_partition()
