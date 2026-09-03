"""
LP06 / M02 - Redis Streams demo (Slide 18)

Durable, coordinated task queue: consumer groups distribute tasks across
workers, unacknowledged tasks stay pending for retry.

Requires:
  pip install redis
  export REDIS_HOST=... REDIS_KEY=...
"""
import os
import time

import redis

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=True,
)

STREAM = "ai:inference:queue"
GROUP = "workers"
CONSUMER = "worker-1"


def setup_consumer_group():
    try:
        r.xgroup_create(STREAM, GROUP, id="0", mkstream=True)
        print(f"Created consumer group '{GROUP}' on stream '{STREAM}'")
    except redis.exceptions.ResponseError as e:
        if "BUSYGROUP" in str(e):
            print(f"Consumer group '{GROUP}' already exists")
        else:
            raise


def produce_tasks():
    for i in range(3):
        task_id = r.xadd(STREAM, {"prompt": f"classify document {i}", "model": "gpt-4o"})
        print(f"Added task {task_id}")


def consume_and_process():
    # Slide 18: XREADGROUP pulls new (">") messages for this consumer group.
    messages = r.xreadgroup(GROUP, CONSUMER, {STREAM: ">"}, count=5, block=2000)
    if not messages:
        print("No new messages")
        return

    for _stream_name, entries in messages:
        for entry_id, fields in entries:
            print(f"Processing {entry_id}: {fields}")
            time.sleep(0.1)  # simulate work
            r.xack(STREAM, GROUP, entry_id)
            print(f"  Acked {entry_id}")


def show_pending():
    # Slide 18: XPENDING reveals tasks that were read but never acked
    # (e.g. a worker crashed mid-processing).
    pending = r.xpending(STREAM, GROUP)
    print(f"Pending summary: {pending}")


if __name__ == "__main__":
    setup_consumer_group()
    produce_tasks()
    consume_and_process()
    show_pending()
