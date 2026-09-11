"""
LP06 / M02 - Redis Streams: consumer groups, competing consumers, retry

Demonstrates (mapped to deck slides):
  - Slide 18: durable, coordinated task queue
  - Slide 18: XADD / XREADGROUP / XACK / XPENDING / XCLAIM
  - The key distinction the deck draws between pub/sub and Streams,
    made concrete with real data:
      - TWO INDEPENDENT CONSUMER GROUPS on the same stream ("notify" and
        "analytics") - each group gets its OWN full copy of every
        message, regardless of what the other group has already
        processed. This is the fan-out behavior Streams share with
        pub/sub.
      - WITHIN one group ("notify"), TWO COMPETING CONSUMERS
        ("worker-1", "worker-2") pull from the SAME group - each message
        goes to exactly one of them, not both. This is the load-
        balancing behavior pub/sub does NOT have.
      - One message is deliberately left unacknowledged (simulating a
        crashed worker) and recovered with XCLAIM, showing Streams'
        reliability guarantee that pub/sub lacks entirely.

Requires:
  pip install redis
  export REDIS_HOST=... REDIS_KEY=...
"""
import os

import redis

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=True,
)

STREAM = "ai:inference:queue"
TASK_COUNT = 12  # enough that competing consumers visibly split the work


def setup_consumer_groups():
    # Two independent groups reading the same stream - "notify" gets its
    # own copy of every message read by "analytics", and vice versa.
    for group in ("notify", "analytics"):
        try:
            r.xgroup_create(STREAM, group, id="0", mkstream=True)
            print(f"Created consumer group '{group}' on stream '{STREAM}'")
        except redis.exceptions.ResponseError as e:
            if "BUSYGROUP" in str(e):
                print(f"Consumer group '{group}' already exists")
            else:
                raise


def produce_tasks():
    ids = []
    for i in range(TASK_COUNT):
        task_id = r.xadd(STREAM, {"prompt": f"classify document {i}", "model": "gpt-4o"})
        ids.append(task_id)
    print(f"Added {TASK_COUNT} tasks to '{STREAM}'")
    return ids


def competing_consumers_demo():
    # Slide 18: within ONE group, multiple consumers split the work -
    # each message is delivered to exactly one of them. Alternates two
    # consumers reading small batches to make the split visible; a real
    # deployment would just run both as separate worker processes.
    print("\n=== Competing consumers within group 'notify' ===")
    counts = {"worker-1": 0, "worker-2": 0}
    for consumer in ["worker-1", "worker-2"] * (TASK_COUNT // 2):
        messages = r.xreadgroup("notify", consumer, {STREAM: ">"}, count=1)
        if not messages:
            break
        for _stream_name, entries in messages:
            for entry_id, fields in entries:
                counts[consumer] += 1
                print(f"  {consumer} got {entry_id}: {fields['prompt']}")
                r.xack(STREAM, "notify", entry_id)
    print(f"Split within group 'notify': {counts} (each task went to exactly one consumer)")


def independent_group_demo():
    # Slide 18: a SEPARATE group sees every message independently, even
    # though 'notify' already consumed and acked all of them above.
    print("\n=== Group 'analytics' reading the same stream independently ===")
    messages = r.xreadgroup("analytics", "analytics-worker", {STREAM: ">"}, count=TASK_COUNT)
    total = sum(len(entries) for _stream_name, entries in messages) if messages else 0
    print(f"Group 'analytics' independently received {total} messages (all {TASK_COUNT}, unaffected by 'notify')")
    for _stream_name, entries in messages:
        for entry_id, _fields in entries:
            r.xack(STREAM, "analytics", entry_id)


def crashed_worker_and_recovery_demo():
    # Slide 18: simulate a worker that reads a message and then crashes
    # before acking it - XPENDING reveals it, XCLAIM lets another
    # consumer take over ownership and finish the job.
    print("\n=== Simulating a crashed worker, then recovering with XCLAIM ===")
    r.xadd(STREAM, {"prompt": "classify urgent document", "model": "gpt-4o"})
    messages = r.xreadgroup("notify", "worker-1", {STREAM: ">"}, count=1)
    entry_id = messages[0][1][0][0]
    print(f"worker-1 read {entry_id} but crashes before acking it (no XACK called)")

    pending = r.xpending(STREAM, "notify")
    print(f"XPENDING for group 'notify': {pending}")

    claimed = r.xclaim(STREAM, "notify", "worker-2", min_idle_time=0, message_ids=[entry_id])
    print(f"worker-2 claims the abandoned message via XCLAIM: {[c[0] for c in claimed]}")
    r.xack(STREAM, "notify", entry_id)
    print(f"worker-2 finishes and acks {entry_id}")

    pending_after = r.xpending(STREAM, "notify")
    print(f"XPENDING for group 'notify' after recovery: {pending_after}")


if __name__ == "__main__":
    setup_consumer_groups()
    produce_tasks()
    competing_consumers_demo()
    independent_group_demo()
    crashed_worker_and_recovery_demo()
