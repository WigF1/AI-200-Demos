"""
LP07 / M01 - Queue send/receive with peek-lock settlement

Demonstrates (mapped to deck slides):
  - Slide 8: structured message (JSON body, correlation_id, application properties)
  - Slide 10: peek-lock receive mode, complete/abandon/dead-letter settlement

Requires:
  pip install azure-servicebus
  export SERVICEBUS_CONNECTION_STRING=...
"""
import json
import os
import uuid

from azure.servicebus import ServiceBusClient, ServiceBusMessage

CONN_STR = os.environ["SERVICEBUS_CONNECTION_STRING"]
QUEUE_NAME = "inference-requests"


def send_messages():
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_sender(QUEUE_NAME) as sender:
            for i in range(3):
                message = ServiceBusMessage(
                    body=json.dumps({
                        "prompt": f"Extract parties from contract {i}",
                        "model": "gpt-4o",
                        "temperature": 0.1,
                    }),
                    content_type="application/json",
                    message_id=str(uuid.uuid4()),
                    correlation_id=f"req-{i}",
                    application_properties={"model_name": "gpt-4o", "priority": "standard"},
                )
                sender.send_messages(message)
                print(f"Sent message req-{i}")


def receive_and_settle():
    # Slide 10: peek-lock (default) - at-least-once delivery, must settle.
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_receiver(QUEUE_NAME, max_wait_time=10) as receiver:
            for msg in receiver:
                try:
                    body = json.loads(str(msg))
                    print(f"Processing {msg.correlation_id}: {body['prompt']}")
                    # ... run_inference(msg) would go here ...
                    receiver.complete_message(msg)
                    print(f"  Completed {msg.correlation_id}")
                except json.JSONDecodeError:
                    receiver.dead_letter_message(msg, reason="MalformedPayload")
                    print(f"  Dead-lettered {msg.correlation_id}: malformed payload")


if __name__ == "__main__":
    send_messages()
    receive_and_settle()
