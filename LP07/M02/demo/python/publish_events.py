"""
LP07 / M02 - Publish a CloudEvent to Azure Event Grid (Slide 22)

Requires:
  pip install azure-eventgrid azure-identity
  export EVENTGRID_TOPIC_ENDPOINT=... EVENTGRID_TOPIC_KEY=...
"""
import os

from azure.core.credentials import AzureKeyCredential
from azure.core.messaging import CloudEvent
from azure.eventgrid import EventGridPublisherClient

ENDPOINT = os.environ["EVENTGRID_TOPIC_ENDPOINT"]
KEY = os.environ["EVENTGRID_TOPIC_KEY"]

client = EventGridPublisherClient(ENDPOINT, AzureKeyCredential(KEY))


def publish_inference_completed_event():
    event = CloudEvent(
        type="com.contoso.ai.InferenceCompleted",
        source="/services/content-moderation",
        data={
            "requestId": "req-78901",
            "modelName": "content-classifier-v3",
            "status": "flagged",  # matches the advanced filter created in 01-create-eventgrid-topic
            "resultLocation": "https://storage.example.com/results/req-78901.json",
        },
        subject="/pipelines/moderation/batch-42",
    )
    client.send(event)
    print(f"Published CloudEvent: {event.type} (status=flagged)")


if __name__ == "__main__":
    publish_inference_completed_event()
