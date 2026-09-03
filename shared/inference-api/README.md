# shared/inference-api

A tiny, dependency-light Flask "AI inference API" used as the demo payload
across the container-hosting learning paths (**LP01** App Service, **LP02**
Container Apps, **LP03** AKS). Using one app for all three lets a room see
the *same* code deployed three different ways, which is the point of
comparing the compute options.

## Endpoints

| Route | Purpose |
|---|---|
| `GET /health` | Liveness/health-check target for App Service health checks, ACA probes, and AKS readiness/liveness probes |
| `GET /config` | Echoes which env vars / app settings / ConfigMap / Secret values actually reached the container (never echoes secret values, only presence/length) |
| `POST /classify` | Fake inference call — body `{"text": "..."}` — so there's something to curl live |
| `GET /crash` | Deliberately throws, for CrashLoopBackOff / restart-troubleshooting demos |

## Why it listens on port 8000

Every platform in this repo has its own "wrong port" failure mode:

- **App Service**: requires `WEBSITES_PORT=8000`
- **Container Apps**: requires `--target-port 8000` on the ingress
- **AKS**: requires the Service's `targetPort: 8000` to match the container port

Using a non-default port (not 80/8080) forces each lab to actually set that
value instead of getting lucky with a platform default — matching the
knowledge-check questions in the decks.

## Local test (no Azure required)

```bash
pip install -r requirements.txt pytest
pytest
```

## Build

```bash
docker build -t inference-api:local .
docker run --rm -p 8000:8000 inference-api:local
curl http://localhost:8000/health
```

Each learning path's module folder has its own provisioning scripts
(`az cli` + PowerShell) that build/push this same Dockerfile via ACR Tasks
and deploy it to the relevant compute target.
