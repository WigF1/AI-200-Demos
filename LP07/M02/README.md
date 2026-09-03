# LP07 / M02 — Develop event-driven AI workflows with Azure Event Grid

**Lab:** [02-eventgrid-publish-receive-events.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/02-eventgrid-publish-receive-events.md)

## Learning objectives (from the deck)
- Explain Event Grid's role in event-driven AI patterns; core components
- Design events with the CloudEvents schema, custom types, filtered subscriptions
- Configure delivery/retry policies and dead-letter destinations
- Publish custom events using the SDK/REST API

## Contents

- `demo/scripts/01-create-eventgrid-topic` (bash/ps1) — Slide 18, 22: custom topic, `cloudeventschemav1_0`
- `demo/python/publish_events.py` — Slide 22: publish a CloudEvent
- `demo/python/create_filtered_subscription.py` — Slide 20, 24: advanced filter on `data.status`

## Run it

```bash
cd demo/scripts && ./01-create-eventgrid-topic.sh   # or .ps1
cd ../python && pip install azure-eventgrid azure-identity && python publish_events.py
```
