"""
LP05 / M01 - Build and query with Azure Database for PostgreSQL

Demonstrates (mapped to deck slides):
  - Slide 8: schema design - BIGSERIAL, JSONB, TIMESTAMPTZ, foreign keys
  - Slide 9: JSONB operators, ON CONFLICT upsert, keyset pagination
  - Slide 10: psycopg 3 ConnectionPool, parameterized queries

Requires:
  pip install "psycopg[binary,pool]"
  export PGHOST=... PGDATABASE=... PGUSER=... PGPASSWORD=... PGSSLMODE=require
"""
import os

from psycopg_pool import ConnectionPool

CONNINFO = (
    f"host={os.environ['PGHOST']} dbname={os.environ['PGDATABASE']} "
    f"user={os.environ['PGUSER']} password={os.environ['PGPASSWORD']} "
    f"sslmode={os.environ.get('PGSSLMODE', 'require')}"
)

# Slide 10: ConnectionPool - reusable connections instead of one per request.
pool = ConnectionPool(conninfo=CONNINFO, min_size=1, max_size=5)

DDL = """
CREATE TABLE IF NOT EXISTS conversations (
  id BIGSERIAL PRIMARY KEY,
  session_id UUID NOT NULL DEFAULT gen_random_uuid(),
  user_id VARCHAR(255) NOT NULL,
  started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  metadata JSONB DEFAULT '{}'
);
CREATE TABLE IF NOT EXISTS messages (
  id BIGSERIAL PRIMARY KEY,
  conversation_id BIGINT NOT NULL REFERENCES conversations(id),
  role VARCHAR(50) NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS user_preferences (
  user_id VARCHAR(255) NOT NULL,
  key VARCHAR(100) NOT NULL,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, key)
);
"""


def setup_schema():
    with pool.connection() as conn:
        conn.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto;")  # for gen_random_uuid()
        conn.execute(DDL)
    print("Schema ready")


def demo_upsert():
    # Slide 9: idempotent insert-or-update via ON CONFLICT.
    with pool.connection() as conn:
        conn.execute(
            """
            INSERT INTO user_preferences (user_id, key, value)
            VALUES (%s, %s, %s)
            ON CONFLICT (user_id, key)
            DO UPDATE SET value = EXCLUDED.value, updated_at = CURRENT_TIMESTAMP
            """,
            ("u1", "theme", "dark"),
        )
    print("Upserted preference: u1.theme = dark")


def demo_jsonb_and_conversation():
    with pool.connection() as conn:
        row = conn.execute(
            """
            INSERT INTO conversations (user_id, metadata)
            VALUES (%s, %s)
            RETURNING id
            """,
            ("u1", '{"channel": "web", "locale": "en-US"}'),
        ).fetchone()
        conversation_id = row[0]

        for role, content in [("user", "hello"), ("assistant", "hi, how can I help?")]:
            conn.execute(
                "INSERT INTO messages (conversation_id, role, content) VALUES (%s, %s, %s)",
                (conversation_id, role, content),
            )

        # JSONB operator: ->> extracts a text value.
        result = conn.execute(
            "SELECT metadata ->> 'channel' AS channel FROM conversations WHERE id = %s",
            (conversation_id,),
        ).fetchone()
        print(f"Conversation {conversation_id} channel (via JSONB ->>): {result[0]}")


def demo_keyset_pagination():
    # Slide 9: keyset pagination avoids the OFFSET performance penalty.
    with pool.connection() as conn:
        page1 = conn.execute(
            """
            SELECT id, content, created_at FROM messages
            ORDER BY created_at DESC, id DESC
            LIMIT 20
            """
        ).fetchall()
        if not page1:
            print("No messages yet")
            return
        last_id, last_ts = page1[-1][0], page1[-1][2]
        page2 = conn.execute(
            """
            SELECT id, content, created_at FROM messages
            WHERE (created_at, id) < (%s, %s)
            ORDER BY created_at DESC, id DESC
            LIMIT 20
            """,
            (last_ts, last_id),
        ).fetchall()
        print(f"Page 1: {len(page1)} rows, Page 2 (keyset): {len(page2)} rows")


if __name__ == "__main__":
    setup_schema()
    demo_upsert()
    demo_jsonb_and_conversation()
    demo_keyset_pagination()
    pool.close()
