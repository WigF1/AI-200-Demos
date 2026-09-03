"""
Demo AI inference API for AI-200T00A Module 1 & 2 (Container Hosting on Azure).

This is intentionally small and dependency-light so it builds fast with
ACR Tasks and is easy to reason about on stage. It demonstrates the exact
touch points called out in the deck and knowledge checks:

  - Listens on port 8000 (NOT 80/8080) -> forces a live WEBSITES_PORT demo
  - Reads configuration from environment variables (App Settings)
  - Reads a "secret" from an env var that would be backed by a Key Vault
    reference (@Microsoft.KeyVault(...)) in App Service
  - Exposes /health for App Service health check path demos
  - Exposes /config to show what actually landed in the container's env
  - Exposes /classify to fake an "AI" call so you have something to
    invoke from curl/Postman during the demo
  - Logs to stdout/stderr so `az webapp log tail` / Log stream has content
"""
import json
import logging
import os
import sys
import time
import uuid

from flask import Flask, jsonify, request

# --- Logging: force stdout so App Service / Kudu / Log stream capture it ---
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
log = logging.getLogger("inference-api")

app = Flask(__name__)

START_TIME = time.time()
IMAGE_VERSION = os.environ.get("IMAGE_VERSION", "dev")

# Used by the LP03/M03 (AKS troubleshooting) demo: setting this env var
# makes the process exit immediately on startup, producing a real
# CrashLoopBackOff for `kubectl describe pod` / Events practice.
if os.environ.get("FORCE_CRASH_DEMO", "").lower() == "true":
    log.error("FORCE_CRASH_DEMO is set - exiting on startup to simulate CrashLoopBackOff")
    sys.exit(1)


@app.get("/health")
def health():
    """App Service health check target: Slide 17, Module 2."""
    return jsonify(status="healthy", uptimeSeconds=round(time.time() - START_TIME, 1))


@app.get("/config")
def show_config():
    """
    Shows which app settings / slot settings / Key Vault references actually
    reached the container. Never echo real secret VALUES in a real app —
    this demo only echoes whether a secret was resolved and its length,
    which is safe to show on screen.
    """
    api_key = os.environ.get("MODEL_API_KEY", "")
    return jsonify(
        environment=os.environ.get("APP_ENVIRONMENT", "not-set"),
        featureXEnabled=os.environ.get("FEATURE_X_ENABLED", "not-set"),
        modelEndpoint=os.environ.get("MODEL_ENDPOINT", "not-set"),
        modelApiKeyResolved=bool(api_key),
        modelApiKeyLength=len(api_key) if api_key else 0,
        websitesPortHint="This app listens on 8000 - set WEBSITES_PORT=8000",
        imageVersion=IMAGE_VERSION,
    )


@app.post("/classify")
def classify():
    """Fake inference endpoint so there's something to call live."""
    body = request.get_json(silent=True) or {}
    text = body.get("text", "")
    request_id = str(uuid.uuid4())

    log.info("request_id=%s classify called, chars=%d", request_id, len(text))

    if not text:
        return jsonify(error="Provide JSON body: {\"text\": \"...\"}"), 400

    # Deterministic "fake" classification so the demo is repeatable
    category = "positive" if len(text) % 2 == 0 else "negative"

    return jsonify(
        requestId=request_id,
        category=category,
        model=os.environ.get("MODEL_ENDPOINT", "local-stub-model"),
        imageVersion=IMAGE_VERSION,
    )


@app.get("/crash")
def crash():
    """
    Deliberately throws, for demonstrating CrashLoopBackOff / App Service
    restart + log stream troubleshooting during the module 2/3 talk track.
    Do NOT wire this into anything except a manual demo click.
    """
    log.error("Simulated crash triggered on purpose for the demo")
    raise RuntimeError("Simulated failure for troubleshooting demo")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    log.info("Starting inference-api on port %d (image=%s)", port, IMAGE_VERSION)
    app.run(host="0.0.0.0", port=port)
