"""
LP06 / M02 - Redis pub/sub demo (Slide 17)

At-most-once, fire-and-forget broadcast to all active subscribers.
Good for: cache invalidation, status updates, config change broadcasts.

Requires:
  pip install redis
  export REDIS_HOST=... REDIS_KEY=...

Usage:
  python pubsub_demo.py subscribe   # run first, in its own terminal
  python pubsub_demo.py publish     # run second, in another terminal
"""
import os
import sys
import time

import redis

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=True,
)

CHANNEL = "ai:models:updated"


def subscribe():
    pubsub = r.pubsub()
    pubsub.subscribe(CHANNEL)
    print(f"Subscribed to '{CHANNEL}'. Waiting for messages (Ctrl+C to stop)...")
    for message in pubsub.listen():
        if message["type"] == "message":
            print(f"Received: {message['data']}")


def publish():
    for version in ["gpt-4o:v1", "gpt-4o:v2", "gpt-4o:v3"]:
        print(f"Publishing: {version}")
        r.publish(CHANNEL, version)
        time.sleep(1)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "subscribe"
    if mode == "subscribe":
        subscribe()
    elif mode == "publish":
        publish()
    else:
        print("Usage: python pubsub_demo.py [subscribe|publish]")
