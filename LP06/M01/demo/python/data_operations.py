"""
LP06 / M01 - Implement data operations in Azure Managed Redis

Demonstrates (mapped to deck slides):
  - Slide 8: core data types - strings, hashes, lists, sets, sorted sets,
    and atomic counters (INCR/DECR)
  - Slide 7: pipelining for batch operations
  - Slide 9: cache invalidation - both manual (explicit DEL) and
    time-based (TTL/EXPIRE), plus the cache-aside pattern
  - Slide 9: iterating over keys - SCAN (non-blocking, production-safe)
    vs KEYS (blocks the server - shown here only to make the contrast
    concrete on a tiny local dataset, never do this against a real cache)

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


def demo_strings():
    r.set("user:1001:name", "Alice")
    print("GET user:1001:name ->", r.get("user:1001:name"))


def demo_hashes():
    r.hset("user:1001", mapping={"name": "Alice", "email": "alice@example.com"})
    print("HGETALL user:1001 ->", r.hgetall("user:1001"))


def demo_lists():
    # Ordered collection - good fit for a recent-activity feed or a
    # simple work queue (LPUSH/RPOP).
    r.delete("user:1001:recent_actions")
    r.lpush("user:1001:recent_actions", "logged_in", "viewed_dashboard", "ran_report")
    print("LRANGE user:1001:recent_actions ->", r.lrange("user:1001:recent_actions", 0, -1))


def demo_sets():
    # Unordered, unique members - good fit for tags, feature flags a
    # user has, or de-duplicating IDs.
    r.delete("user:1001:tags")
    r.sadd("user:1001:tags", "beta-tester", "premium", "premium")  # duplicate is a no-op
    print("SMEMBERS user:1001:tags ->", r.smembers("user:1001:tags"))
    print("SISMEMBER user:1001:tags premium ->", r.sismember("user:1001:tags", "premium"))


def demo_sorted_sets():
    # Members ordered by a score - good fit for leaderboards or a
    # priority queue.
    r.delete("leaderboard:weekly")
    r.zadd("leaderboard:weekly", {"alice": 42, "bob": 57, "carol": 31})
    print("Top 2, highest score first ->", r.zrevrange("leaderboard:weekly", 0, 1, withscores=True))
    r.zincrby("leaderboard:weekly", 10, "alice")
    print("Alice's score after +10 ->", r.zscore("leaderboard:weekly", "alice"))


def demo_numeric_counters():
    # Slide 8: atomic INCR/DECR for counters and rate limiting - no
    # read-modify-write race condition, unlike GET/SET yourself.
    r.delete("api:calls:user1001", "rate_limit:user1001")
    for _ in range(3):
        r.incr("api:calls:user1001")
    print("Total API calls (INCR x3) ->", r.get("api:calls:user1001"))

    r.set("rate_limit:user1001", 5)
    remaining = r.decrby("rate_limit:user1001", 2)
    print("Rate limit remaining after 2 requests (DECRBY) ->", remaining)


def demo_pipelining():
    # Slide 7: batch multiple reads into one round-trip instead of one
    # round-trip per command.
    r.hset("user:1002", mapping={"name": "Bob"})
    pipe = r.pipeline()
    pipe.hgetall("user:1001")
    pipe.hgetall("user:1002")
    results = pipe.execute()
    print(f"Pipelined 2 HGETALLs in one round trip: {results}")


def demo_manual_invalidation():
    # Slide 9: manual invalidation - delete the cache key the moment you
    # know the underlying data changed, rather than waiting for a TTL.
    r.set("product:42:price", "19.99")
    print("Cached price before update ->", r.get("product:42:price"))
    print("(source price changes in the database...)")
    r.delete("product:42:price")
    print("Cached price after manual invalidation ->", r.get("product:42:price"), "(None = evicted)")


def demo_ttl_invalidation():
    # Slide 9: SETEX sets value + TTL atomically; time-based invalidation
    # needs no application code to run later - Redis expires the key
    # itself. Uses a short TTL here so the demo can actually show it
    # happening, not just print the configured value.
    r.setex("session:abc123", 2, "active")
    print("TTL right after SETEX (2s) ->", r.ttl("session:abc123"), "seconds")
    print("Waiting 3s for it to expire...")
    time.sleep(3)
    print("GET after expiry ->", r.get("session:abc123"), "(None = Redis expired it automatically)")

    r.set("session:no-ttl", "active")
    print("TTL on a key with no expiry set ->", r.ttl("session:no-ttl"), "(-1 = never expires)")
    print("TTL on a key that doesn't exist ->", r.ttl("session:does-not-exist"), "(-2 = key doesn't exist)")


def demo_cache_aside(user_id: str):
    # Slide 9: cache-aside - check cache, fetch "from DB" on miss, store
    # with TTL so it self-invalidates even if nothing ever calls DEL.
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


def demo_key_iteration():
    # Slide 9: SCAN is cursor-based and non-blocking - it returns a small
    # batch per call and lets other clients keep working in between.
    # KEYS walks the entire keyspace in one blocking call - fine on this
    # tiny local demo, but on a real cache with millions of keys it
    # freezes every other client until it finishes. Never use it in
    # production; scan_iter() (which wraps SCAN in a loop for you) is
    # the direct replacement.
    r.mset({"session:aaa": "1", "session:bbb": "1", "session:ccc": "1"})

    print("Keys found via SCAN (session:*):")
    scanned = sorted(r.scan_iter(match="session:*"))
    for key in scanned:
        print(f"  {key}")

    print("Keys found via KEYS (session:*) - same result here, but blocking at scale:")
    print(" ", sorted(r.keys("session:*")))

    print(f"Total matching keys: {len(scanned)}")


if __name__ == "__main__":
    demo_strings()
    demo_hashes()
    demo_lists()
    demo_sets()
    demo_sorted_sets()
    demo_numeric_counters()
    demo_pipelining()
    demo_manual_invalidation()
    demo_ttl_invalidation()
    demo_cache_aside("user-42")
    demo_cache_aside("user-42")  # second call should be a cache hit
    demo_key_iteration()
