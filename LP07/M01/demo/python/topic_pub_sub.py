"""
LP07 / M01 - Topic fan-out demo (Slide 7 / knowledge check Q1)

A document-analysis result needs to reach 3 independent services
(notification, audit, dashboard). A topic with 3 subscriptions delivers a
copy of every message to each subscription, independently.

Requires:
  pip install azure-servicebus
  export SERVICEBUS_CONNECTION_STRING=...
Run 01-create-servicebus first (creates the topic with subscriptions
'notifications' and 'audit'; add a third 'dashboard' subscription the same
way if you want the full 3-way fan-out from the knowledge check).
"""
import json
import os

from azure.servicebus import ServiceBusClient, ServiceBusMessage

CONN_STR = os.environ["SERVICEBUS_CONNECTION_STRING"]
TOPIC_NAME = "inference-results"


def publish_result():
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_topic_sender(TOPIC_NAME) as sender:
            message = ServiceBusMessage(
                body=json.dumps({"documentId": "doc-42", "status": "analysis-complete"}),
                content_type="application/json",
            )
            sender.send_messages(message)
            print("Published result to topic - every subscription gets its own copy")


def read_from_subscription(subscription_name: str):
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_subscription_receiver(
            topic_name=TOPIC_NAME, subscription_name=subscription_name, max_wait_time=5
        ) as receiver:
            for msg in receiver:
                print(f"[{subscription_name}] received: {str(msg)}")
                receiver.complete_message(msg)


if __name__ == "__main__":
    publish_result()
    read_from_subscription("notifications")
    read_from_subscription("audit")
