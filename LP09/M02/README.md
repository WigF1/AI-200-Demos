# LP09 / M02 — Analyze app telemetry with logs and metrics

**Lab:** [02-query-logs-kql.md](https://github.com/MicrosoftLearning/mslearn-azure-ai/blob/main/instructions/instrument-observe/02-query-logs-kql.md)

## Learning objectives (from the deck)
- Write KQL queries against Application Insights telemetry
- Explore logs for error patterns and performance bottlenecks
- Build dashboards and Azure Monitor Workbooks
- Configure alert rules for failures/degradation/anomalies

## Contents

- `demo/kql/queries.kql` — Slide 19-21: all the query patterns from the deck (hourly aggregation, sampling-aware exception counts, percentile latency, dependency failure analysis)
- `demo/scripts/01-create-alert-rule` (bash/ps1) — Slide 23-24: log search alert + action group

## Run it

Generate some traffic against the app from LP09/M01 first (a few `/classify`
calls, including an empty-body call to trigger the exception path), then
run the queries in `queries.kql` against the Application Insights resource
in the Azure portal **Logs** blade (or via `az monitor app-insights query`).
