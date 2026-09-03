"""
LP05 / M03 - Optimize vector search in Azure Database for PostgreSQL

Demonstrates (mapped to deck slides):
  - Slide 30: EXPLAIN ANALYZE to validate index usage, SET for search params
  - Slide 32: metadata pre-filter (B-tree on category) narrows candidates
    before the vector distance calculation
  - Slide 34: session-scoped tuning with SET LOCAL inside a transaction

Requires:
  pip install "psycopg[binary,pool]" pgvector
Run LP05/M02's schema/seed scripts first so document_chunks has data.
"""
import os
import random

from pgvector.psycopg import register_vector
from psycopg_pool import ConnectionPool

CONNINFO = (
    f"host={os.environ['PGHOST']} dbname={os.environ['PGDATABASE']} "
    f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']} "
    f"sslmode={os.environ.get('PGSSLMODE', 'require')}"
)
DIMENSIONS = 1536

pool = ConnectionPool(conninfo=CONNINFO, min_size=1, max_size=5)


def fake_embedding(seed: int) -> list[float]:
    rnd = random.Random(seed)
    return [rnd.uniform(-1, 1) for _ in range(DIMENSIONS)]


def add_category_column_and_index():
    # Slide 32: structured column + B-tree index for common filters.
    with pool.connection() as conn:
        conn.execute(
            "ALTER TABLE document_chunks ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'networking';"
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS document_chunks_category_idx ON document_chunks (category);"
        )
    print("category column + B-tree index ready")


def explain_analyze_vector_query():
    query_vector = fake_embedding(0)
    with pool.connection() as conn:
        register_vector(conn)
        rows = conn.execute(
            """
            EXPLAIN ANALYZE
            SELECT content FROM document_chunks
            ORDER BY embedding <=> %s
            LIMIT 10
            """,
            (query_vector,),
        ).fetchall()
    print("EXPLAIN ANALYZE plan (confirm the HNSW/IVFFlat index is used, not a Seq Scan):")
    for row in rows:
        print(" ", row[0])


def filtered_vector_query_with_session_tuning():
    query_vector = fake_embedding(0)
    with pool.connection() as conn:
        register_vector(conn)
        with conn.transaction():
            # Slide 34: SET LOCAL scopes the tuning knob to this transaction only.
            conn.execute("SET LOCAL hnsw.ef_search = 150;")
            rows = conn.execute(
                """
                SELECT content, embedding <=> %s AS distance
                FROM document_chunks
                WHERE category = %s
                ORDER BY embedding <=> %s
                LIMIT 5
                """,
                (query_vector, "networking", query_vector),
            ).fetchall()
    print("Filtered + tuned vector search results:")
    for content, distance in rows:
        print(f"  [{distance:.4f}] {content}")


if __name__ == "__main__":
    add_category_column_and_index()
    explain_analyze_vector_query()
    filtered_vector_query_with_session_tuning()
    pool.close()
