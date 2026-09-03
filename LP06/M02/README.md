# LP06 / M02 — Stream and coordinate events in Azure Redis

**Lab:** [02-amr-pub-sub.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/azure-managed-redis/02-amr-pub-sub.md)

## Learning objectives (from the deck)
- Explain Redis pub/sub for broadcasting events
- Implement Redis Streams for reliable task queues with retry/failure recovery
- Choose between pub/sub (broadcast) and Streams (coordinated distribution)
- Build Python apps using both patterns

## Contents

- `demo/python/pubsub_demo.py` — Slide 17: publisher/subscriber, pattern subscription
- `demo/python/streams_demo.py` — Slide 18: `XADD`/`XREADGROUP`/`XACK`/`XPENDING`/`XCLAIM` consumer-group workflow

No new resource needed — reuses the cache created in LP06/M01.

## Run it

Open two terminals:

```bash
# Terminal 1
python pubsub_demo.py subscribe
# Terminal 2
python pubsub_demo.py publish

# Streams: single terminal is enough
python streams_demo.py
```
