"""
LP04 / M03 - Optimize query performance for Azure Cosmos DB for NoSQL

Demonstrates (mapped to deck slides):
  - Slide 31: read the RU charge per query (x-ms-request-charge) and use it
    to compare an unindexed scan vs. an indexed filter+sort query
  - Slide 34/35 knowledge check: low index utilization / high
    retrieved-to-output ratio indicates a missing index

Requires:
  pip install azure-cosmos
  export COSMOS_ENDPOINT=... COSMOS_KEY=...
Run 01-apply-indexing-policy first for the indexed comparison to be meaningful.
"""
import os

from azure.cosmos import CosmosClient

ENDPOINT = os.environ["COSMOS_ENDPOINT"]
KEY = os.environ["COSMOS_KEY"]
DATABASE_NAME = "ragstore"
CONTAINER_NAME = "documents"

client = CosmosClient(ENDPOINT, credential=KEY)
database = client.get_database_client(DATABASE_NAME)
container = database.get_container_client(CONTAINER_NAME)


def run_and_report(label: str, query: str, parameters=None, partition_key=None):
    kwargs = {"query": query, "parameters": parameters or []}
    if partition_key is not None:
        kwargs["partition_key"] = partition_key
    else:
        kwargs["enable_cross_partition_query"] = True

    query_iterable = container.query_items(**kwargs)
    items = list(query_iterable)

    # The Python SDK exposes per-request charge via the response headers on
    # the underlying client - the simplest reliable read is the aggregate
    # request charge tracked in the container proxy's last response.
    charge = container.client_connection.last_response_headers.get(
        "x-ms-request-charge", "n/a"
    )
    print(f"{label}: {len(items)} item(s), RU charge={charge}")
    return items


if __name__ == "__main__":
    # Unindexed / broad filter: relies on a full scan if no supporting index.
    run_and_report(
        "Broad scan (no composite index helps here)",
        "SELECT * FROM c WHERE c.price > @minPrice",
        parameters=[{"name": "@minPrice", "value": 0}],
    )

    # Matches the composite index created in 01-apply-indexing-policy.sh:
    # documentType (asc) + uploadDate (desc).
    run_and_report(
        "Indexed filter + sort (documentType + uploadDate)",
        """
        SELECT * FROM c
        WHERE c.documentType = @docType
        ORDER BY c.uploadDate DESC
        """,
        parameters=[{"name": "@docType", "value": "pdf"}],
    )

    print(
        "\nCompare the two RU charges above. If the indexed query isn't "
        "meaningfully cheaper, re-check that the composite index property "
        "order exactly matches the ORDER BY clause (Slide 34 knowledge check)."
    )
