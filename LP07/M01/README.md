# LP07 / M01 — Queue and process AI operations with Azure Service Bus

**Lab:** [01-svcbus-process-messages.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/01-svcbus-process-messages.md)

## Learning objectives (from the deck)
- Explain how Service Bus decouples AI components; load leveling, competing consumers, pub-sub
- Choose between queues and topics/subscriptions
- Structure messages: serialization, large payloads (claim-check), correlation tracking
- Process messages reliably: peek-lock, poison messages, dead-letter queues

## Contents

- `demo/scripts/01-create-servicebus` (bash/ps1) — Slide 5, 7: namespace, queue, topic + subscriptions (audit has a `requires_audit = TRUE` filter rule)
- `demo/python/queue_send_receive.py` — Slide 8, 10: structured message + peek-lock settlement (complete/abandon/dead-letter); `send`/`receive` subcommands for the competing-consumers, lock-expiry and max-delivery-count walkthrough below
- `demo/python/topic_pub_sub.py` — Slide 7: fan-out to independent subscriptions, plus a SQL subscription filter (10 results published: `notifications` gets all 10, `audit` only the 5 flagged `requires_audit`)
- `demo/python/inspect_dlq.py` — Slide 11: read the dead-letter sub-queue

## Run it

```bash
cd demo/scripts && ./01-create-servicebus.sh   # or .ps1
cd ../python && pip install azure-servicebus && python queue_send_receive.py
```

### Competing consumers, lock expiry, and poison messages

The queue has a 1-minute lock duration and max delivery count 5.

```bash
python queue_send_receive.py send --count 100
python queue_send_receive.py receive --max 20                 # in order, completed

# Two terminals at once: competing consumers. Each message goes to exactly one.
python queue_send_receive.py receive --delay-ms 2000

# Abort after receive, before settle: Ctrl+C during the 2s pause (a hard
# exit, like a crash) or --crash-after 1. The message stays locked for 1 min,
# then comes back out of sequence with delivery_count incremented.
python queue_send_receive.py receive --delay-ms 2000
python queue_send_receive.py receive --crash-after 1

# Repeat the abort on the same message. On the delivery after
# delivery_count=4, it moves to the DLQ (MaxDeliveryCountExceeded).
python inspect_dlq.py
```

`delivery_count` counts *prior* failed deliveries, so the first receive shows 0.
