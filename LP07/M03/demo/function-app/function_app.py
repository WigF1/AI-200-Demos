"""
LP07 / M03 - Azure Functions (Python v2 programming model)

Demonstrates (mapped to deck slides):
  - Slide 32: HTTP trigger for a synchronous inference endpoint
  - Slide 33: Service Bus queue trigger + Blob output binding (declarative,
    no SDK boilerplate) for async batch processing
  - Slide 34: SDK client (would call Document Intelligence/OpenAI/AI Search
    here) initialized at module level for reuse across invocations
"""
import json
import logging
import os

import azure.functions as func

app = func.FunctionApp()


def perform_classification(text: str) -> str:
    """Stand-in for a real model call - deterministic so the demo is repeatable."""
    return "positive" if len(text) % 2 == 0 else "negative"


# Slide 32: HTTP trigger - inference endpoint.
@app.route(route="classify", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def classify_document(req: func.HttpRequest) -> func.HttpResponse:
    payload = req.get_json()
    result = perform_classification(payload.get("text", ""))
    logging.info("classify_document processed %d chars", len(payload.get("text", "")))
    return func.HttpResponse(
        json.dumps({"category": result}),
        status_code=200,
        mimetype="application/json",
    )


# Slide 33: Service Bus trigger picks up queued work items; blob output
# binding writes results without any storage SDK boilerplate.
@app.service_bus_queue_trigger(
    arg_name="msg",
    queue_name="document-jobs",
    connection="ServiceBusConnection",  # identity-based: ServiceBusConnection__fullyQualifiedNamespace
)
@app.blob_output(
    arg_name="output_blob",
    path="results/{rand-guid}.json",
    connection="AzureWebJobsStorage",
)
def process_and_store(msg: func.ServiceBusMessage, output_blob: func.Out[str]) -> None:
    job = json.loads(msg.get_body().decode("utf-8"))
    logging.info("Processing job for document_url=%s", job.get("document_url"))
    result = {
        "document_url": job.get("document_url"),
        "category": perform_classification(job.get("document_url", "")),
    }
    output_blob.set(json.dumps(result))
