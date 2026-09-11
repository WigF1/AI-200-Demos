"""
LP06 / M02 - Redis pub/sub demo (Slide 17)

At-most-once, fire-and-forget broadcast to all active subscribers.
Good for: cache invalidation, status updates, config change broadcasts.
Contrast with streams_demo.py: nothing here persists, and a subscriber
that isn't listening at publish time simply never sees that message -
there's no XPENDING/XCLAIM equivalent, by design.

Requires:
  pip install redis
  export REDIS_HOST=... REDIS_KEY=...

Usage:
  python pubsub_demo.py            # single-process demo: subscribes in
                                    # a background thread, publishes from
                                    # the main thread, then reports what
                                    # was actually received
  python pubsub_demo.py subscribe  # live 2-terminal demo: run this first
  python pubsub_demo.py publish    # then this, in a second terminal
"""
import os
import sys
import threading
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
MESSAGES = ["gpt-4o:v1", "gpt-4o:v2", "gpt-4o:v3"]


def subscribe():
    pubsub = r.pubsub()
    pubsub.subscribe(CHANNEL)
    print(f"Subscribed to '{CHANNEL}'. Waiting for messages (Ctrl+C to stop)...")
    for message in pubsub.listen():
        if message["type"] == "message":
            print(f"Received: {message['data']}")


def publish():
    for version in MESSAGES:
        print(f"Publishing: {version}")
        r.publish(CHANNEL, version)
        time.sleep(1)


def single_process_demo():
    # Runs both sides in one script, for testing and for a quick
    # single-terminal walkthrough - a real subscriber and publisher are
    # normally separate processes (see the subscribe/publish modes
    # above), but the mechanics are identical either way.
    received = []
    pubsub = r.pubsub()
    pubsub.subscribe(CHANNEL)
    pubsub.get_message(timeout=1)  # discard the "subscribe" confirmation message

    def listener():
        for message in pubsub.listen():
            if message["type"] == "message":
                received.append(message["data"])
                print(f"  Subscriber received: {message['data']}")

    thread = threading.Thread(target=listener, daemon=True)
    thread.start()
    time.sleep(0.2)  # give the subscriber a moment to actually be listening

    print(f"Publishing {len(MESSAGES)} messages to '{CHANNEL}'...")
    for version in MESSAGES:
        r.publish(CHANNEL, version)
        time.sleep(0.1)
    time.sleep(0.5)  # let the last message be delivered

    pubsub.close()
    print(f"\nSubscriber received {len(received)}/{len(MESSAGES)} messages: {received}")
    print(
        "(At-most-once delivery: a subscriber connecting even a moment after publish()\n"
        " finishes would receive 0 of these - unlike Streams, nothing is stored for it\n"
        " to catch up on. Try starting 'python pubsub_demo.py subscribe' in one terminal\n"
        " AFTER running 'python pubsub_demo.py publish' in another to see this directly.)"
    )


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "demo"
    if mode == "subscribe":
        subscribe()
    elif mode == "publish":
        publish()
    elif mode == "demo":
        single_process_demo()
    else:
        print("Usage: python pubsub_demo.py [demo|subscribe|publish]")
