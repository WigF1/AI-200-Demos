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
    # A modestly larger, more varied set than a bare minimum - enough
    # that TOP N results are actually a subset (not "everything"), and
    # that filtering by category has more than one candidate to filter
    # from. Still well under the 1,000-vector threshold where
    # quantizedFlat/diskANN indexes actually activate (see Slide 30) -
    # that's specifically what LP04/M03's compare_index_types.py is for.
    docs = [
        {"id": "kb-1", "category": "networking", "title": "WiFi troubleshooting",
         "content": "Common WiFi issues and fixes"},
        {"id": "kb-2", "category": "networking", "title": "VPN setup guide",
         "content": "Configure a corporate VPN client"},
        {"id": "kb-3", "category": "networking", "title": "DNS resolution failures",
         "content": "Diagnosing and fixing DNS lookup errors"},
        {"id": "kb-4", "category": "networking", "title": "Slow network diagnostics",
         "content": "Steps to identify network bottlenecks"},
        {"id": "kb-5", "category": "hardware", "title": "Laptop battery replacement",
         "content": "Steps to replace a laptop battery"},
        {"id": "kb-6", "category": "hardware", "title": "Printer not responding",
         "content": "Troubleshooting a printer that won't print"},
        {"id": "kb-7", "category": "hardware", "title": "Monitor display artifacts",
         "content": "Fixing flickering or distorted monitor output"},
        {"id": "kb-8", "category": "software", "title": "Application crash on startup",
         "content": "Diagnosing why an app fails to launch"},
        {"id": "kb-9", "category": "software", "title": "License activation errors",
         "content": "Resolving software license activation failures"},
        {"id": "kb-10", "category": "software", "title": "Slow application performance",
         "content": "Identifying causes of sluggish application behavior"},
        {"id": "kb-11", "category": "security", "title": "Password reset process",
         "content": "Steps to reset a forgotten account password"},
        {"id": "kb-12", "category": "security", "title": "Suspicious login alert",
         "content": "What to do after an unrecognized login attempt"},
        {"id": "kb-13", "category": "security", "title": "Multi-factor authentication setup",
         "content": "Enabling MFA on a corporate account"},
        {"id": "kb-14", "category": "cloud", "title": "Storage account access denied",
         "content": "Fixing permission errors on cloud storage"},
        {"id": "kb-15", "category": "cloud", "title": "Virtual machine won't start",
         "content": "Diagnosing a VM stuck in a failed state"},
        {"id": "kb-16", "category": "cloud", "title": "Unexpected billing spike",
         "content": "Investigating an unusual increase in cloud costs"},
    ]
    for i, d in enumerate(docs):
        d["embedding"] = fake_embedding(i + 1)
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
