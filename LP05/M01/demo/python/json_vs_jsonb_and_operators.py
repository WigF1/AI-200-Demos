"""
LP05 / M01 - JSON vs JSONB: insert/query performance, and practical
operator walkthroughs

Demonstrates:
  - Insert and query performance comparison between the `json` and
    `jsonb` column types on identical data (Slide 8's JSONB guidance).
    json stores the input text as-is (cheap to write, needs re-parsing
    on every read); jsonb parses into a decomposed binary format up
    front (a bit more work to write, much cheaper to read/query, and
    the only one of the two that supports indexing or most operators).
  - Every commonly used jsonb operator, with a runnable example each:
      Extraction       (work on BOTH json and jsonb): -> ->> #> #>>
      Containment/existence (jsonb only): @> <@ ? ?| ?&
      JSON path              (jsonb only): @? @@
      Modification/concat    (jsonb only): || -

Requires:
  pip install "psycopg[binary,pool]"
  export PGHOST=... PGDATABASE=... PGUSER=... PGPASSWORD=... PGSSLMODE=require
"""
import os
import time

from psycopg_pool import ConnectionPool
from psycopg.types.json import Json, Jsonb

CONNINFO = (
    f"host={os.environ['PGHOST']} dbname={os.environ['PGDATABASE']} "
    f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']} "
    f"sslmode={os.environ.get('PGSSLMODE', 'require')}"
)

pool = ConnectionPool(conninfo=CONNINFO, min_size=1, max_size=5)

ROW_COUNT = 2000  # enough to show a measurable difference without a long wait

DDL = """
DROP TABLE IF EXISTS perf_test_json;
DROP TABLE IF EXISTS perf_test_jsonb;
CREATE TABLE perf_test_json (
  id BIGSERIAL PRIMARY KEY,
  payload JSON NOT NULL
);
CREATE TABLE perf_test_jsonb (
  id BIGSERIAL PRIMARY KEY,
  payload JSONB NOT NULL
);
CREATE TABLE IF NOT EXISTS operator_demo (
  id BIGSERIAL PRIMARY KEY,
  data JSONB NOT NULL
);
"""


def setup_schema():
    with pool.connection() as conn:
        conn.execute(DDL)
    print("Schema ready: perf_test_json, perf_test_jsonb, operator_demo")


def sample_payload(i: int) -> dict:
    # A small product-catalog-style document, with a nested object and
    # an array, so there's something interesting for the later operator
    # demos to extract/filter/modify.
    return {
        "sku": f"SKU-{i:05d}",
        "name": f"Widget {i}",
        "price": round(9.99 + (i % 50), 2),
        "in_stock": i % 3 != 0,
        "attributes": {
            "color": ["red", "blue", "green"][i % 3],
            "weight_kg": round(0.1 + (i % 10) * 0.05, 2),
        },
        "tags": ["sale", "new", "clearance"][: (i % 3) + 1],
    }


def seed_and_time_inserts():
    payloads = [sample_payload(i) for i in range(ROW_COUNT)]

    with pool.connection() as conn:
        start = time.perf_counter()
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO perf_test_json (payload) VALUES (%s)",
                [(Json(p),) for p in payloads],
            )
        conn.commit()
        json_seconds = time.perf_counter() - start

        start = time.perf_counter()
        with conn.cursor() as cur:
            cur.executemany(
                "INSERT INTO perf_test_jsonb (payload) VALUES (%s)",
                [(Jsonb(p),) for p in payloads],
            )
        conn.commit()
        jsonb_seconds = time.perf_counter() - start

    print(f"\nInsert {ROW_COUNT} rows:")
    print(f"  json:  {json_seconds:.2f}s")
    print(f"  jsonb: {jsonb_seconds:.2f}s")
    print(
        "  (json is often marginally faster to write since it stores the exact\n"
        "   input text; jsonb spends a bit more time up front decomposing into\n"
        "   a binary format, which is what makes it faster to query below.)"
    )


def time_query(label, sql):
    with pool.connection() as conn:
        start = time.perf_counter()
        conn.execute(sql).fetchall()
        elapsed = time.perf_counter() - start
    print(f"  {label}: {elapsed:.3f}s")


def compare_query_performance():
    print(f"\nQuery all {ROW_COUNT} rows, extracting one field:")
    time_query("json  (payload->>'name')", "SELECT payload->>'name' FROM perf_test_json")
    time_query("jsonb (payload->>'name')", "SELECT payload->>'name' FROM perf_test_jsonb")

    print("\nFilter by a nested field (no index on either table yet - see LP05/M03 for GIN indexing):")
    time_query(
        "json  (nested color = 'red')",
        "SELECT id FROM perf_test_json WHERE payload->'attributes'->>'color' = 'red'",
    )
    time_query(
        "jsonb (nested color = 'red')",
        "SELECT id FROM perf_test_jsonb WHERE payload->'attributes'->>'color' = 'red'",
    )
    print(
        "  (jsonb's binary format avoids re-parsing text on every row, which tends\n"
        "   to widen its advantage as the filter gets more complex - and jsonb is\n"
        "   the only one that can use a GIN index to skip the scan entirely.)"
    )


def seed_operator_demo_data():
    with pool.connection() as conn:
        existing = conn.execute("SELECT COUNT(*) FROM operator_demo").fetchone()[0]
        if existing:
            print(f"\noperator_demo already has {existing} row(s) - skipping seed")
            return
        conn.execute(
            "INSERT INTO operator_demo (data) VALUES (%s)",
            (Jsonb({
                "sku": "SKU-00001",
                "name": "Widget 1",
                "price": 19.99,
                "in_stock": True,
                "attributes": {"color": "red", "weight_kg": 0.45},
                "tags": ["sale", "new"],
            }),),
        )
    print("\nSeeded 1 row into operator_demo for the operator walkthrough")


def run_operator_demo(label, sql):
    with pool.connection() as conn:
        result = conn.execute(sql).fetchone()
    print(f"  {label}")
    print(f"    SQL: {' '.join(sql.split())}")
    print(f"    ->  {result[0] if result else None}")


def demo_extraction_operators():
    # -> / ->> / #> / #>> work on BOTH json and jsonb - the only
    # operators that do. Shown here against jsonb for consistency with
    # the rest of the demo.
    print("\n=== Extraction operators (work on both json and jsonb) ===")
    run_operator_demo(
        "-> returns a field as jsonb (here: a nested object)",
        "SELECT data -> 'attributes' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "->> returns a field as text",
        "SELECT data ->> 'name' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "#> returns a nested path as jsonb (here: two levels deep in one step)",
        "SELECT data #> '{attributes,weight_kg}' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "#>> returns a nested path as text",
        "SELECT data #>> '{attributes,color}' FROM operator_demo LIMIT 1",
    )


def demo_containment_and_existence_operators():
    # jsonb only - none of these five have a json equivalent.
    print("\n=== Containment / existence operators (jsonb only) ===")
    run_operator_demo(
        "@> does the left value contain the right value",
        "SELECT data @> '{\"in_stock\": true}' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "<@ is the left value contained by the right value (operands reversed vs @>)",
        "SELECT '{\"in_stock\": true}'::jsonb <@ data FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "? does this top-level key exist",
        "SELECT data ? 'price' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "?| does ANY of these top-level keys exist",
        "SELECT data ?| array['price', 'does_not_exist'] FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "?& do ALL of these top-level keys exist",
        "SELECT data ?& array['price', 'name'] FROM operator_demo LIMIT 1",
    )


def demo_jsonpath_operators():
    # jsonb only. The right operand is a jsonpath expression, not plain
    # text - note the filter syntax ?(...) inside the path below is part
    # of the jsonpath language itself, unrelated to the top-level ?
    # existence operator demoed above even though both use "?".
    print("\n=== JSON path operators (jsonb only) ===")
    run_operator_demo(
        "@? does this jsonpath query return any item",
        "SELECT data @? '$.price ? (@ > 10)' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "@@ does this jsonpath boolean predicate evaluate true",
        "SELECT data @@ '$.in_stock == true' FROM operator_demo LIMIT 1",
    )


def demo_modification_operators():
    # jsonb only.
    print("\n=== Modification / concatenation operators (jsonb only) ===")
    run_operator_demo(
        "|| merges two objects at the top level (right side wins on key conflicts)",
        "SELECT data || '{\"price\": 24.99, \"on_sale\": true}'::jsonb FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "- text removes a single key",
        "SELECT data - 'tags' FROM operator_demo LIMIT 1",
    )
    run_operator_demo(
        "- text[] removes several keys at once",
        "SELECT data - array['tags', 'attributes'] FROM operator_demo LIMIT 1",
    )


if __name__ == "__main__":
    setup_schema()
    seed_and_time_inserts()
    compare_query_performance()
    seed_operator_demo_data()
    demo_extraction_operators()
    demo_containment_and_existence_operators()
    demo_jsonpath_operators()
    demo_modification_operators()
    pool.close()
