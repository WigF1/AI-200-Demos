"""
LP05 / M02 - Implement vector search with Azure Database for PostgreSQL (pgvector)

Demonstrates (mapped to deck slides):
  - Slide 18: vector(n) column alongside relational metadata
  - Slide 18: distance operators (<->  L2, <=> cosine, <#> negative inner product)
  - Slide 19: HNSW index creation
  - Slide 22: RAG retrieval pattern - source_documents + document_chunks

Requires:
  pip install "psycopg[binary,pool]" pgvector
  export PGHOST=... PGDATABASE=... PGUSER=... PGPASSWORD=... PGSSLMODE=require
Run 01-enable-pgvector.sh/.ps1 first.
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


def setup_schema():
    with pool.connection() as conn:
        conn.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        register_vector(conn)
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS source_documents (
                id SERIAL PRIMARY KEY,
                title TEXT NOT NULL,
                category TEXT
            );
            CREATE TABLE IF NOT EXISTS document_chunks (
                id SERIAL PRIMARY KEY,
                document_id INT REFERENCES source_documents(id),
                chunk_index INT NOT NULL,
                content TEXT NOT NULL,
                embedding vector({DIMENSIONS}),
                token_count INT
            );
        """)
    print("pgvector schema ready")


def seed_chunks():
    with pool.connection() as conn:
        register_vector(conn)
        doc_id = conn.execute(
            "INSERT INTO source_documents (title, category) VALUES (%s, %s) RETURNING id",
            ("WiFi troubleshooting guide", "networking"),
        ).fetchone()[0]

        chunks = [
            "Restart the router and modem before anything else.",
            "Check that the WiFi password matches the one on the router label.",
            "Move closer to the access point to rule out signal strength issues.",
        ]
        for i, text in enumerate(chunks):
            conn.execute(
                """
                INSERT INTO document_chunks (document_id, chunk_index, content, embedding, token_count)
                VALUES (%s, %s, %s, %s, %s)
                """,
                (doc_id, i, text, fake_embedding(i), len(text.split())),
            )
    print(f"Seeded 3 chunks for document {doc_id}")


def create_hnsw_index():
    # Slide 19: HNSW - higher recall, incremental inserts, good default for
    # production RAG. (IVFFlat needs existing data + is faster to build on
    # very large static collections - see links.md.)
    with pool.connection() as conn:
        conn.execute(
            """
            CREATE INDEX IF NOT EXISTS document_chunks_embedding_hnsw_idx
            ON document_chunks
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64)
            """
        )
    print("HNSW index created (or already existed)")


def demo_similarity_search():
    query_vector = fake_embedding(0)  # pretend this is the user's query embedding
    with pool.connection() as conn:
        register_vector(conn)
        conn.execute("SET hnsw.ef_search = 100;")  # Slide 30: search-time recall/speed knob
        rows = conn.execute(
            """
            SELECT content, embedding <=> %s AS distance
            FROM document_chunks
            ORDER BY embedding <=> %s
            LIMIT 3
            """,
            (query_vector, query_vector),
        ).fetchall()
    print("Top matching chunks (cosine distance, lower = more similar):")
    for content, distance in rows:
        print(f"  [{distance:.4f}] {content}")


if __name__ == "__main__":
    setup_schema()
    seed_chunks()
    create_hnsw_index()
    demo_similarity_search()
    pool.close()
