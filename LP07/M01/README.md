# LP07 / M01 — Queue and process AI operations with Azure Service Bus

**Lab:** [01-svcbus-process-messages.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/01-svcbus-process-messages.md)

## Learning objectives (from the deck)
- Explain how Service Bus decouples AI components; load leveling, competing consumers, pub-sub
- Choose between queues and topics/subscriptions
- Structure messages: serialization, large payloads (claim-check), correlation tracking
- Process messages reliably: peek-lock, poison messages, dead-letter queues

## Contents

- `demo/scripts/01-create-servicebus` (bash/ps1) — Slide 5, 7: namespace, queue, topic + subscriptions
- `demo/python/queue_send_receive.py` — Slide 8, 10: structured message + peek-lock settlement (complete/abandon/dead-letter)
- `demo/python/topic_pub_sub.py` — Slide 7: fan-out to independent subscriptions
- `demo/python/inspect_dlq.py` — Slide 11: read the dead-letter sub-queue

## Run it

```bash
cd demo/scripts && ./01-create-servicebus.sh   # or .ps1
cd ../python && pip install azure-servicebus && python queue_send_receive.py
```
