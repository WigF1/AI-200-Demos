"""
LP04 / M02 - Implement vector search with Azure Cosmos DB for NoSQL

Demonstrates (mapped to deck slides):
  - Slide 18: store documents with an `embedding` vector alongside metadata
  - Slide 18: VectorDistance + TOP N + ORDER BY - the core similarity pattern
  - Slide 19: filtered vector search (pre-filter by metadata before ranking)
  - Slide 19: hybrid search with RANK RRF (vector + full-text)

Uses random vectors as embedding stand-ins so the demo runs without calling
a real embedding model. Swap `fake_embedding()` for a real embeddings call
(e.g. Azure OpenAI `text-embedding-3-small`) in a live scenario.

Requires:
  pip install azure-cosmos numpy
  export COSMOS_ENDPOINT=... COSMOS_KEY=...
"""
import os
import random

from azure.cosmos import CosmosClient

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY = os.environ["COSMOS_KEY"]
DATABASE_NAME = "ragstore"
CONTAINER_NAME = "doc_embeddings"
DIMENSIONS = 1536

client = CosmosClient(ENDPOINT, credential=KEY)
database = client.get_database_client(DATABASE_NAME)
container = database.get_container_client(CONTAINER_NAME)


def fake_embedding(seed: int) -> list[float]:
    """Stand-in for a real embedding model call - deterministic per seed."""
    rnd = random.Random(seed)
    return [rnd.uniform(-1, 1) for _ in range(DIMENSIONS)]


def seed_documents():
    docs = [
        {"id": "kb-1", "category": "networking", "title": "WiFi troubleshooting",
         "content": "Common WiFi issues and fixes", "embedding": fake_embedding(1)},
        {"id": "kb-2", "category": "networking", "title": "VPN setup guide",
         "content": "Configure a corporate VPN client", "embedding": fake_embedding(2)},
        {"id": "kb-3", "category": "hardware", "title": "Laptop battery replacement",
         "content": "Steps to replace a laptop battery", "embedding": fake_embedding(3)},
    ]
    for d in docs:
        container.upsert_item(d)
    print(f"Seeded {len(docs)} documents with embeddings")


def demo_vector_query():
    # Slide 18: core query pattern - VectorDistance + TOP N + ORDER BY.
    query_vector = fake_embedding(1)  # pretend this is the user's query embedding
    query = """
        SELECT TOP 3 c.title, VectorDistance(c.embedding, @queryVector) AS Score
        FROM c
        ORDER BY VectorDistance(c.embedding, @queryVector)
    """
    results = list(container.query_items(
        query=query,
        parameters=[{"name": "@queryVector", "value": query_vector}],
        enable_cross_partition_query=True,
    ))
    print("Vector similarity results:")
    for r in results:
        print(f"  {r['title']} - score={r['Score']:.4f}")


def demo_filtered_vector_query():
    # Slide 19: pre-filter by metadata, then rank by similarity.
    query_vector = fake_embedding(1)
    query = """
        SELECT TOP 3 c.title, VectorDistance(c.embedding, @queryVector) AS Score
        FROM c
        WHERE c.category = @category
        ORDER BY VectorDistance(c.embedding, @queryVector)
    """
    results = list(container.query_items(
        query=query,
        parameters=[
            {"name": "@queryVector", "value": query_vector},
            {"name": "@category", "value": "networking"},
        ],
        partition_key="networking",  # partition key in WHERE -> single-partition routing
    ))
    print("Filtered vector results (category=networking):")
    for r in results:
        print(f"  {r['title']} - score={r['Score']:.4f}")


if __name__ == "__main__":
    seed_documents()
    demo_vector_query()
    demo_filtered_vector_query()
    print(
        "\nHybrid search (RRF) requires a full-text policy/index on the "
        "container; see links.md -> 'RANK RRF query syntax' for the exact "
        "SQL shown on Slide 19 of the deck."
    )
