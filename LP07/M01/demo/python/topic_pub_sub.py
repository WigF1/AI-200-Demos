"""
LP07 / M01 - Topic fan-out + subscription filters (Slide 7 / knowledge check Q1)

A document-analysis result needs to reach independent services
(notification, audit, dashboard). A topic delivers a copy of each message
to every subscription whose rules match it, independently:

  - notifications: default rule (1=1) - gets every result
  - audit: SQL filter `requires_audit = TRUE` - only results flagged for
    audit, matched against the message's application properties

This publishes 10 results and flags every other one for audit, so
notifications receives 10 and audit receives 5. The filtering happens in
Service Bus, not in the receiver - audit never sees the other 5.

Requires:
  pip install azure-servicebus
  export SERVICEBUS_CONNECTION_STRING=...
Run 01-create-servicebus first (creates the topic, subscriptions
'notifications' and 'audit', and audit's filter rule; add a third
'dashboard' subscription the same way if you want the full 3-way fan-out
from the knowledge check).
"""
import json
import os

from azure.servicebus import ServiceBusClient, ServiceBusMessage

CONN_STR = os.environ["SERVICEBUS_CONNECTION_STRING"]
TOPIC_NAME = "inference-results"
RESULT_COUNT = 10


def publish_results():
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_topic_sender(TOPIC_NAME) as sender:
            messages = []
            for i in range(RESULT_COUNT):
                requires_audit = i % 2 == 0  # 5 of 10 - e.g. documents with PII
                messages.append(ServiceBusMessage(
                    body=json.dumps({"documentId": f"doc-{i}", "status": "analysis-complete"}),
                    content_type="application/json",
                    # Subscription filters match on application properties
                    # (and system properties), never on the body.
                    application_properties={"requires_audit": requires_audit},
                ))
                print(f"Publishing doc-{i}  requires_audit={requires_audit}")
            sender.send_messages(messages)
            print(f"Published {RESULT_COUNT} results - each goes to every subscription whose rule matches\n")


def read_from_subscription(subscription_name: str):
    received = 0
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_subscription_receiver(
            topic_name=TOPIC_NAME, subscription_name=subscription_name, max_wait_time=5
        ) as receiver:
            for msg in receiver:
                received += 1
                print(f"[{subscription_name}] received: {str(msg)}  "
                      f"requires_audit={msg.application_properties.get(b'requires_audit')}")
                receiver.complete_message(msg)
    print(f"[{subscription_name}] total: {received}\n")


if __name__ == "__main__":
    publish_results()
    read_from_subscription("notifications")
    read_from_subscription("audit")
