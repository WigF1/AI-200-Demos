# LP09 / M01 — Instrument an app with OpenTelemetry

**Lab:** [01-instrument-app-opentelemetry.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/instrument-observe/01-instrument-app-opentelemetry.md)

## Learning objectives (from the deck)
- Explain vendor-neutral observability with OpenTelemetry
- Add/configure the Azure Monitor OpenTelemetry Distro
- Create custom spans/traces for request flows
- Export telemetry to Application Insights
- Use trace data to identify/debug distributed performance issues

## Contents

- `demo/scripts/01-create-app-insights` (bash/ps1) — Slide 9: Log Analytics workspace + Application Insights, connection string
- `demo/python/instrumented_app.py` — Slide 7-8: Distro config, `service.name`/`service.namespace` (Application Map), custom spans + attributes

## Run it

```bash
cd demo/scripts && ./01-create-app-insights.sh   # or .ps1
cd ../python && pip install azure-monitor-opentelemetry flask && export APPLICATIONINSIGHTS_CONNECTION_STRING=<from above>
python instrumented_app.py
curl -X POST http://localhost:8000/classify -d '{"text":"hello"}' -H 'Content-Type: application/json'
```

Then open Application Insights → Application Map / End-to-end transaction
view in the portal to see the resulting spans.
