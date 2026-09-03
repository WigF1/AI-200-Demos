"""
LP09 / M01 - Instrument a Flask app with the Azure Monitor OpenTelemetry Distro

Demonstrates (mapped to deck slides):
  - Slide 7: configure_azure_monitor with service.name/service.namespace
    for the Application Map
  - Slide 8: custom spans, attributes, nested spans, SpanKind
  - Slide 8: exception recording / error status on unhandled failures

Requires:
  pip install azure-monitor-opentelemetry flask
  export APPLICATIONINSIGHTS_CONNECTION_STRING=<from 01-create-app-insights>
"""
import json
import time

from azure.monitor.opentelemetry import configure_azure_monitor
from flask import Flask, jsonify, request
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource

# Slide 7: cloud role name identifies this service on the Application Map.
configure_azure_monitor(
    resource=Resource.create({
        "service.name": "inference-api",
        "service.namespace": "ai-200-demo",
        "service.instance.id": "instance-1",
    })
)

app = Flask(__name__)
tracer = trace.get_tracer("inference-api")  # Slide 8: one tracer per service


def generate_embedding(text: str) -> list[float]:
    time.sleep(0.05)  # simulate model latency
    return [0.0] * 8


@app.post("/classify")
def classify():
    body = request.get_json(silent=True) or {}
    text = body.get("text", "")

    # Slide 8: custom span with business-context attributes.
    with tracer.start_as_current_span("GenerateEmbedding") as span:
        span.set_attribute("embedding.model", "text-embedding-ada-002")
        span.set_attribute("embedding.token_count", len(text.split()))
        embedding = generate_embedding(text)
        span.set_attribute("embedding.dimension_count", len(embedding))

    if not text:
        # Deliberately raise to demonstrate exception recording on Slide 8.
        with tracer.start_as_current_span("ValidateInput"):
            raise ValueError("text must not be empty")

    return jsonify(category="positive" if len(text) % 2 == 0 else "negative")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
