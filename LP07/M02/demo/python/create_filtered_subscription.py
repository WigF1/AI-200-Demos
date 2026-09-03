"""
LP07 / M02 - Create a filtered event subscription via the Azure mgmt SDK
(Slide 20, 24: type filtering vs. subject filtering vs. advanced filtering)

This mirrors what 01-create-eventgrid-topic.sh/.ps1 already does with the
CLI - included here as the SDK-equivalent for the "publish custom events
from AI applications using the Event Grid SDK" learning objective.

Requires:
  pip install azure-mgmt-eventgrid azure-identity
  export AZURE_SUBSCRIPTION_ID=... RESOURCE_GROUP=... EVENTGRID_TOPIC=...
"""
import os

from azure.identity import DefaultAzureCredential
from azure.mgmt.eventgrid import EventGridManagementClient
from azure.mgmt.eventgrid.models import (
    EventSubscription,
    EventSubscriptionFilter,
    AdvancedFilter,
    StringInAdvancedFilter,
    WebHookEventSubscriptionDestination,
)

SUBSCRIPTION_ID = os.environ["AZURE_SUBSCRIPTION_ID"]
RESOURCE_GROUP = os.environ["RESOURCE_GROUP"]
TOPIC_NAME = os.environ["EVENTGRID_TOPIC"]

client = EventGridManagementClient(DefaultAzureCredential(), SUBSCRIPTION_ID)


def create_subject_filtered_subscription():
    # Slide 20: subject filtering - prefix/suffix path matching.
    subscription = EventSubscription(
        destination=WebHookEventSubscriptionDestination(
            endpoint_url="https://example.com/webhook-placeholder"
        ),
        filter=EventSubscriptionFilter(
            subject_begins_with="/pipelines/moderation/",
            included_event_types=["com.contoso.ai.InferenceCompleted"],
        ),
    )
    poller = client.event_subscriptions.begin_create_or_update(
        scope=(
            f"/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RESOURCE_GROUP}"
            f"/providers/Microsoft.EventGrid/topics/{TOPIC_NAME}"
        ),
        event_subscription_name="moderation-pipeline-sub",
        event_subscription_info=subscription,
    )
    result = poller.result()
    print(f"Created subject-filtered subscription: {result.name}")


def create_advanced_filtered_subscription():
    # Slide 24: advanced filtering with StringIn on a data payload field.
    subscription = EventSubscription(
        destination=WebHookEventSubscriptionDestination(
            endpoint_url="https://example.com/webhook-placeholder"
        ),
        filter=EventSubscriptionFilter(
            advanced_filters=[
                StringInAdvancedFilter(key="data.status", values=["flagged"])
            ]
        ),
    )
    poller = client.event_subscriptions.begin_create_or_update(
        scope=(
            f"/subscriptions/{SUBSCRIPTION_ID}/resourceGroups/{RESOURCE_GROUP}"
            f"/providers/Microsoft.EventGrid/topics/{TOPIC_NAME}"
        ),
        event_subscription_name="moderation-flagged-sub-sdk",
        event_subscription_info=subscription,
    )
    result = poller.result()
    print(f"Created advanced-filtered subscription: {result.name}")


if __name__ == "__main__":
    create_subject_filtered_subscription()
    create_advanced_filtered_subscription()
