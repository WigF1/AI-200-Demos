# LP07 / M02 — Develop event-driven AI workflows with Azure Event Grid

**Lab:** [02-eventgrid-publish-receive-events.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/integrate-services/02-eventgrid-publish-receive-events.md)

## Learning objectives (from the deck)
- Explain Event Grid's role in event-driven AI patterns; core components
- Design events with the CloudEvents schema, custom types, filtered subscriptions
- Configure delivery/retry policies and dead-letter destinations
- Publish custom events using the SDK/REST API

## Contents

- `demo/scripts/01-create-eventgrid-topic` (bash/ps1) — Slide 18, 22: custom topic, `cloudeventschemav1_0`, plus the [Event Grid Viewer](https://github.com/Azure-Samples/azure-event-grid-viewer) sample web app (F1 App Service) as the webhook handler
- `demo/scripts/02-create-event-subscriptions` (bash/ps1) — Slide 20, 24: filtered subscription (`data.status StringIn flagged`) delivering to the viewer's `/api/updates`
- `demo/python/publish_events.py` — Slide 22: publish a CloudEvent
- `demo/python/create_filtered_subscription.py` — Slide 20, 24: SDK equivalent (subject + advanced filters), also delivering to the viewer (`VIEWER_ENDPOINT`)

## Run it

```bash
cd demo/scripts && ./01-create-eventgrid-topic.sh   # or .ps1 - topic + viewer web app (~2-3 min)
```

**Wait for that to finish, then open `https://evgviewer-<suffix>.azurewebsites.net` (URL printed by the script) and let the page load *before* creating any subscriptions.** Event Grid validates the webhook endpoint as each subscription is created, so the viewer must be awake to answer. The first request to a sleeping F1 app can take 30s or more. With the viewer open:

```bash
./02-create-event-subscriptions.sh                 # or .ps1
cd ../python && pip install azure-eventgrid azure-identity && python publish_events.py
```

The published event appears in the viewer within a few seconds.

**About subscription validation:** this topic uses the CloudEvents schema, so Event Grid validates the endpoint with the CloudEvents webhook handshake: an HTTP `OPTIONS` request carrying `WebHook-Request-Origin`, answered with `WebHook-Allowed-Origin`. The viewer answers it but **doesn't display it**. Only Event Grid-schema subscriptions get a POSTed `SubscriptionValidation` event that the viewer shows. The subscription create succeeding (it waits for the handshake) is the visible proof. Point that out instead of waiting for a validation entry in the viewer.

Teardown: `99-cleanup` deletes the topic, the viewer web app, and its App Service plan.
