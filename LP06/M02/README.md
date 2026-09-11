# LP06 / M02 — Stream and coordinate events in Azure Redis

**Lab:** [02-amr-pub-sub.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/02-amr-pub-sub.md)

## Learning objectives (from the deck)
- Explain Redis pub/sub for broadcasting events
- Implement Redis Streams for reliable task queues with retry/failure recovery
- Choose between pub/sub (broadcast) and Streams (coordinated distribution)
- Build Python apps using both patterns

## Contents

- `demo/python/pubsub_demo.py` — Slide 17: publisher/subscriber. Runs as a single-process demo by default (`python pubsub_demo.py`, subscribes in a background thread so it's fully testable and self-contained), or as a live two-terminal demo (`subscribe`/`publish` modes) to show at-most-once delivery directly - a subscriber that starts after `publish` finishes receives nothing, since nothing is stored for it to catch up on.
- `demo/python/streams_demo.py` — Slide 18: `XADD`/`XREADGROUP`/`XACK`/`XPENDING`/`XCLAIM`. Seeds 12 tasks and demonstrates the distinction the deck draws between pub/sub and Streams with real data: two independent consumer groups (`notify`, `analytics`) each receive their own full copy of every message regardless of what the other group already processed, while two competing consumers (`worker-1`, `worker-2`) *within* the `notify` group split the same 12 tasks between them (confirmed 6/6 in testing) - plus a simulated crashed worker recovered via `XCLAIM`.

Verified end-to-end by running both actual scripts against a local `redis-server` before shipping - not just written and assumed correct.

No new resource needed — reuses the cache created in LP06/M01.

## Run it

```bash
pip install redis

# Pub/sub: single-process demo (or open two terminals for subscribe/publish)
python pubsub_demo.py

# Streams: single terminal is enough
python streams_demo.py
```
