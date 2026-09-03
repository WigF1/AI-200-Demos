"""
LP06 / M01 - Implement data operations in Azure Managed Redis

Demonstrates (mapped to deck slides):
  - Slide 8: default port 10000, TLS, strings/hashes
  - Slide 7: pipelining for batch operations
  - Slide 9: SETEX/EXPIRE, TTL semantics, cache-aside pattern

Requires:
  pip install redis
  export REDIS_HOST=... REDIS_KEY=...
"""
import os
import time

import redis

r = redis.Redis(
    host=os.environ["REDIS_HOST"],
    port=10000,  # Slide 8: default TLS port for Azure Managed Redis
    password=os.environ["REDIS_KEY"],
    ssl=True,
    decode_responses=True,
)


def demo_strings_and_hashes():
    r.set("user:1001:name", "Alice")
    print("GET user:1001:name ->", r.get("user:1001:name"))

    r.hset("user:1001", mapping={"name": "Alice", "email": "alice@example.com"})
    print("HGETALL user:1001 ->", r.hgetall("user:1001"))


def demo_pipelining():
    # Slide 7: batch multiple hash reads into one round-trip.
    r.hset("user:1002", mapping={"name": "Bob"})
    pipe = r.pipeline()
    pipe.hgetall("user:1001")
    pipe.hgetall("user:1002")
    results = pipe.execute()
    print(f"Pipelined 2 HGETALLs in one round trip: {results}")


def demo_expiration():
    # Slide 9: SETEX sets value + TTL atomically.
    r.setex("session:abc123", 30, "active")
    print("TTL session:abc123 ->", r.ttl("session:abc123"), "seconds")

    r.set("session:no-ttl", "active")
    print("TTL session:no-ttl (no expiry set) ->", r.ttl("session:no-ttl"), "(-1 = no expiration)")
    print("TTL session:does-not-exist ->", r.ttl("session:does-not-exist"), "(-2 = key doesn't exist)")


def demo_cache_aside(user_id: str):
    # Slide 9: cache-aside - check cache, fetch "from DB" on miss, store with TTL.
    cache_key = f"model_result:{user_id}"
    cached = r.get(cache_key)
    if cached:
        print(f"Cache HIT for {user_id}: {cached}")
        return cached

    print(f"Cache MISS for {user_id} - simulating a slow model call...")
    time.sleep(0.2)
    result = f"classification-result-for-{user_id}"
    r.setex(cache_key, 300, result)  # cache for 5 minutes
    return result


def demo_pattern_invalidation():
    # Slide 9: pattern-based invalidation using SCAN (never KEYS in production).
    for key in r.scan_iter(match="session:*"):
        print(f"Would invalidate: {key}")


if __name__ == "__main__":
    demo_strings_and_hashes()
    demo_pipelining()
    demo_expiration()
    demo_cache_aside("user-42")
    demo_cache_aside("user-42")  # second call should be a cache hit
    demo_pattern_invalidation()
