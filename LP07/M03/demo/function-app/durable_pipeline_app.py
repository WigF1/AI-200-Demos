"""
LP07 / M03 - Durable Functions for long-running AI pipelines (Lab 04:
04-durable-functions-ai.md)

Demonstrates the async request-reply pattern called out on Slide 30:
"HTTP triggers face a 230-second load balancer timeout; accept request,
queue work, return 202" - Durable Functions' orchestrator pattern is the
managed way to implement that without hand-rolling a queue + status store.

This is a separate function app project (Durable Functions needs the
azure-functions-durable extension) - keep it in its own folder if you
deploy it alongside function_app.py, or merge the trigger definitions if
you prefer a single app.

Requires:
  pip install azure-functions azure-functions-durable
"""
import azure.functions as func
import azure.durable_functions as df

my_app = df.DFApp(http_auth_level=func.AuthLevel.FUNCTION)


# HTTP starter: client calls this, gets a 202 + status URLs immediately -
# no waiting on the 230s load balancer timeout for a multi-minute pipeline.
@my_app.route(route="start-document-pipeline")
@my_app.durable_client_input(client_name="client")
async def start_document_pipeline(req: func.HttpRequest, client) -> func.HttpResponse:
    payload = req.get_json()
    instance_id = await client.start_new("document_pipeline_orchestrator", client_input=payload)
    return client.create_check_status_response(req, instance_id)


# Orchestrator: fan-out/fan-in across activities - chunk, embed, and
# summarize a document, each step a separately retryable activity function.
@my_app.orchestration_trigger(context_name="context")
def document_pipeline_orchestrator(context: df.DurableOrchestrationContext):
    document_url = context.get_input()["document_url"]

    chunks = yield context.call_activity("chunk_document", document_url)

    # Fan-out: embed every chunk in parallel, fan-in: wait for all results.
    embedding_tasks = [context.call_activity("embed_chunk", chunk) for chunk in chunks]
    embeddings = yield context.task_all(embedding_tasks)

    summary = yield context.call_activity("summarize_document", chunks)

    return {"document_url": document_url, "chunk_count": len(chunks), "summary": summary,
            "embedding_count": len(embeddings)}


@my_app.activity_trigger(input_name="documentUrl")
def chunk_document(documentUrl: str) -> list[str]:
    # Stand-in for real chunking logic (e.g. by tokens/sentences).
    return [f"{documentUrl}#chunk-{i}" for i in range(3)]


@my_app.activity_trigger(input_name="chunk")
def embed_chunk(chunk: str) -> list[float]:
    # Stand-in for a real embeddings call.
    return [0.0] * 8


@my_app.activity_trigger(input_name="chunks")
def summarize_document(chunks: list) -> str:
    # Stand-in for a real LLM summarization call.
    return f"Summary covering {len(chunks)} chunks"
