"""
LP07 / M01 - Inspect the dead-letter queue (Slide 11)

Send one intentionally malformed message, let queue_send_receive.py's
dead-letter path catch it, then read it back from the DLQ sub-queue.

Requires:
  pip install azure-servicebus
  export SERVICEBUS_CONNECTION_STRING=...
"""
import os

from azure.servicebus import ServiceBusClient, ServiceBusMessage, ServiceBusSubQueue

CONN_STR = os.environ["SERVICEBUS_CONNECTION_STRING"]
QUEUE_NAME = "inference-requests"


def send_malformed_message():
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_sender(QUEUE_NAME) as sender:
            # Not valid JSON - queue_send_receive.py's receiver will dead-letter this.
            sender.send_messages(ServiceBusMessage(body="{not valid json"))
            print("Sent a malformed message (run queue_send_receive.py's receiver to dead-letter it)")


def inspect_dlq():
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_receiver(
            queue_name=QUEUE_NAME,
            sub_queue=ServiceBusSubQueue.DEAD_LETTER,
            max_wait_time=10,
        ) as dlq_receiver:
            found = False
            for msg in dlq_receiver:
                found = True
                print(f"DLQ message: reason={msg.dead_letter_reason}, "
                      f"description={msg.dead_letter_error_description}")
                dlq_receiver.complete_message(msg)
            if not found:
                print("DLQ is empty (run send_malformed_message + the M01 receiver first)")


if __name__ == "__main__":
    send_malformed_message()
    inspect_dlq()
