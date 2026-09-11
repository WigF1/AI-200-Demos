"""
LP05 / M02 - Implement vector search with Azure Database for PostgreSQL (pgvector)

Demonstrates (mapped to deck slides):
  - Slide 18: vector(n) column alongside relational metadata
  - Slide 18: distance operators (<->  L2, <=> cosine, <#> negative inner product)
  - Slide 19: IVFFlat vs HNSW - real seeded data, build time, and query time
    compared side by side, not just "here's how you create each one."
  - Slide 22: RAG retrieval pattern - source_documents + document_chunks

Requires:
  pip install "psycopg[binary,pool]" pgvector
  export PGHOST=... PGDATABASE=... PGUSER=... PGPASSWORD=... PGSSLMODE=require
Run 01-enable-pgvector.sh/.ps1 first.
"""
import math
import os
import random
import time

from pgvector import Vector
from pgvector.psycopg import register_vector
from psycopg_pool import ConnectionPool

CONNINFO = (
    f"host={os.environ['PGHOST']} dbname={os.environ['PGDATABASE']} "
    f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']} "
    f"sslmode={os.environ.get('PGSSLMODE', 'require')}"
)
DIMENSIONS = 1536
BULK_ROW_COUNT = 3000  # bump this for a more pronounced difference; costs more time/RUs to seed
IVFFLAT_LISTS = round(math.sqrt(BULK_ROW_COUNT))  # Slide 30's own stated heuristic: lists = sqrt(rows)
QUERY_REPEATS = 5  # each timed query runs this many times; the average is reported

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
                (doc_id, i, text, Vector(fake_embedding(i)), len(text.split())),
            )
    print(f"Seeded 3 chunks for document {doc_id}")


def setup_bulk_table():
    # Separate from document_chunks so the small RAG demo above stays
    # easy to reason about - this table exists purely to make the index
    # comparison below meaningful at a size where the two index types'
    # tradeoffs actually show up.
    with pool.connection() as conn:
        conn.execute(f"""
            CREATE TABLE IF NOT EXISTS bulk_embeddings (
                id SERIAL PRIMARY KEY,
                category TEXT,
                embedding vector({DIMENSIONS})
            );
        """)
    print("bulk_embeddings table ready")


def seed_bulk_embeddings():
    categories = ["networking", "hardware", "software", "security", "cloud"]
    with pool.connection() as conn:
        register_vector(conn)
        existing = conn.execute("SELECT COUNT(*) FROM bulk_embeddings").fetchone()[0]
        if existing >= BULK_ROW_COUNT:
            print(f"bulk_embeddings already has {existing} rows - skipping seed")
            return
        start = time.perf_counter()
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO bulk_embeddings (category, embedding) VALUES (%s, %s)",
                [
                    (categories[i % len(categories)], Vector(fake_embedding(10_000 + i)))
                    for i in range(BULK_ROW_COUNT)
                ],
            )
        conn.commit()
    print(f"Seeded {BULK_ROW_COUNT} rows into bulk_embeddings in {time.perf_counter() - start:.1f}s")

    # Without this, the planner can still be working from stale/default
    # statistics right after a bulk insert (autovacuum's own ANALYZE runs
    # asynchronously and isn't guaranteed to have completed yet) and choose
    # a sequential scan over either index - confirmed happening in testing:
    # HNSW's query silently fell back to a Seq Scan without this, making
    # the "comparison" actually measure brute-force scan time for HNSW.
    with pool.connection() as conn:
        conn.execute("ANALYZE bulk_embeddings;")
    print("Ran ANALYZE so the planner has current statistics before either index is tested")


def drop_comparison_indexes():
    with pool.connection() as conn:
        conn.execute("DROP INDEX IF EXISTS bulk_embeddings_ivfflat_idx;")
        conn.execute("DROP INDEX IF EXISTS bulk_embeddings_hnsw_idx;")


def build_ivfflat_index() -> float:
    # IVFFlat needs existing data to build its clusters from - it must
    # run AFTER seeding, unlike HNSW which can be created on an empty
    # table (Slide 19). lists = sqrt(rows) is the deck's own heuristic.
    with pool.connection() as conn:
        start = time.perf_counter()
        conn.execute(
            f"""
            CREATE INDEX bulk_embeddings_ivfflat_idx
            ON bulk_embeddings
            USING ivfflat (embedding vector_cosine_ops)
            WITH (lists = {IVFFLAT_LISTS})
            """
        )
        elapsed = time.perf_counter() - start
    print(f"IVFFlat index built in {elapsed:.2f}s (lists={IVFFLAT_LISTS})")
    return elapsed


def build_hnsw_index() -> float:
    with pool.connection() as conn:
        start = time.perf_counter()
        conn.execute(
            """
            CREATE INDEX bulk_embeddings_hnsw_idx
            ON bulk_embeddings
            USING hnsw (embedding vector_cosine_ops)
            WITH (m = 16, ef_construction = 64)
            """
        )
        elapsed = time.perf_counter() - start
    print(f"HNSW index built in {elapsed:.2f}s (m=16, ef_construction=64)")
    return elapsed


def confirm_index_used(index_name: str, query_vector):
    # Sanity check that the index is actually usable here, not that the
    # planner would pick it unprompted at this row count. Confirmed while
    # testing: at a few thousand rows, PostgreSQL's cost estimator often
    # (reasonably) judges a sequential scan + sort as cheaper than an ANN
    # index scan, and will silently use the scan instead - which would
    # make this "comparison" actually measure scan time for whichever
    # index the planner skipped. Forcing enable_seqscan off, scoped to
    # this one check via SET LOCAL inside a transaction, is a standard
    # technique for isolating an index's own behavior during benchmarking
    # - it does not reflect what the planner would choose unprompted in
    # production, which is a separate, valid decision on its own data.
    with pool.connection() as conn:
        with conn.transaction():
            conn.execute("SET LOCAL enable_seqscan = off;")
            plan = conn.execute(
                "EXPLAIN (COSTS OFF) SELECT id FROM bulk_embeddings ORDER BY embedding <=> %s LIMIT 10",
                (query_vector,),
            ).fetchall()
    plan_text = " ".join(row[0] for row in plan)
    used = index_name in plan_text
    print(f"  Usable via {index_name}: {'yes' if used else 'NO - check plan: ' + plan_text}")


def time_query(query_vector) -> float:
    # Same enable_seqscan=off technique as confirm_index_used, and for
    # the same reason: without it, a query against whichever index the
    # planner currently disfavors at this row count would silently run
    # as a sequential scan instead, making the timing comparison compare
    # the wrong thing for that index.
    times = []
    for _ in range(QUERY_REPEATS):
        with pool.connection() as conn:
            with conn.transaction():
                conn.execute("SET LOCAL enable_seqscan = off;")
                start = time.perf_counter()
                conn.execute(
                    "SELECT id FROM bulk_embeddings ORDER BY embedding <=> %s LIMIT 10",
                    (query_vector,),
                ).fetchall()
                times.append(time.perf_counter() - start)
    return sum(times) / len(times)


def compare_ivfflat_vs_hnsw():
    query_vector = Vector(fake_embedding(10_000))  # matches the first seeded row exactly

    drop_comparison_indexes()

    print("\n=== IVFFlat ===")
    ivfflat_build_seconds = build_ivfflat_index()
    confirm_index_used("bulk_embeddings_ivfflat_idx", query_vector)
    ivfflat_query_seconds = time_query(query_vector)
    print(f"  Avg query time over {QUERY_REPEATS} runs: {ivfflat_query_seconds * 1000:.1f}ms")

    print("\n=== HNSW ===")
    with pool.connection() as conn:
        conn.execute("DROP INDEX IF EXISTS bulk_embeddings_ivfflat_idx;")
    hnsw_build_seconds = build_hnsw_index()
    confirm_index_used("bulk_embeddings_hnsw_idx", query_vector)
    hnsw_query_seconds = time_query(query_vector)
    print(f"  Avg query time over {QUERY_REPEATS} runs: {hnsw_query_seconds * 1000:.1f}ms")

    print(f"\n=== Summary ({BULK_ROW_COUNT} rows, {DIMENSIONS} dimensions) ===")
    print(f"{'Index':<10} {'Build (s)':<12} {'Avg query (ms)':<15}")
    print(f"{'IVFFlat':<10} {ivfflat_build_seconds:<12.2f} {ivfflat_query_seconds * 1000:<15.1f}")
    print(f"{'HNSW':<10} {hnsw_build_seconds:<12.2f} {hnsw_query_seconds * 1000:<15.1f}")
    print(
        "\n(Slide 19/31: IVFFlat typically builds faster and uses less memory; HNSW\n"
        " typically gives higher recall and more consistent query latency, at the\n"
        " cost of a slower build. Both queries above force enable_seqscan off to\n"
        " isolate each index's own timing - confirmed while building this demo that\n"
        f" PostgreSQL's planner reasonably prefers a plain sequential scan over either\n"
        f" index at only {BULK_ROW_COUNT} rows, which would otherwise silently measure scan\n"
        " time instead of index time for whichever one it skipped. That planner\n"
        " choice is itself worth knowing: an index this data volume doesn't actually\n"
        " need won't get used in production either, regardless of which type it is.)"
    )


def demo_similarity_search():
    # A plain Python list still fails against vector operators like <=>
    # even after register_vector(conn) - register_vector's automatic
    # casting only kicks in for column-assignment contexts (e.g. INSERT
    # into a vector(n) column), not bare operator usage. Wrapping in
    # pgvector's own Vector() type is what actually fixes it - confirmed
    # by reproducing the exact failure locally before applying this fix.
    query_vector = Vector(fake_embedding(0))  # pretend this is the user's query embedding
    with pool.connection() as conn:
        register_vector(conn)
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
    demo_similarity_search()

    setup_bulk_table()
    seed_bulk_embeddings()
    compare_ivfflat_vs_hnsw()

    pool.close()
