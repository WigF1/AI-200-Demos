"""
LP07 / M01 - Queue send/receive with peek-lock settlement

Demonstrates (mapped to deck slides):
  - Slide 8: structured message (JSON body, correlation_id, application properties)
  - Slide 10: peek-lock receive mode, complete/abandon/dead-letter settlement
  - Slide 7: competing consumers - run `receive` in two terminals at once
  - Slide 11: poison messages - abort before settling repeatedly and the
    message lands in the DLQ once it exceeds the queue's max delivery
    count (5, set by 01-create-servicebus)

Usage:
  python queue_send_receive.py                  # original demo: send 3, receive + complete
  python queue_send_receive.py send --count 100
  python queue_send_receive.py receive [--max 20] [--delay-ms 2000] [--crash-after N]

Walkthrough:
  1. `send --count 100`, then `receive --max 20` - drains 20 in order.
  2. Two terminals, both `receive --delay-ms 2000` - competing consumers;
     each message goes to exactly one of them, so each terminal shows
     gaps in the sequence numbers.
  3. `receive --delay-ms 2000` and press Ctrl+C during the pause (or use
     `--crash-after 1`) - the process dies after receiving but before
     settling. Ctrl+C here is a hard exit, not a clean shutdown, to
     simulate a crashed consumer. The message stays locked (invisible)
     until its lock expires, then comes back with a higher delivery count,
     out of sequence relative to messages received in the meantime.
  4. Repeat step 3 on the same message - after the 5th failed delivery
     Service Bus moves it to the DLQ (reason MaxDeliveryCountExceeded);
     read it with inspect_dlq.py.

Requires:
  pip install azure-servicebus
  export SERVICEBUS_CONNECTION_STRING=...
"""
import argparse
import json
import os
import signal
import sys
import time
import uuid

from azure.servicebus import ServiceBusClient, ServiceBusMessage

CONN_STR = os.environ["SERVICEBUS_CONNECTION_STRING"]
QUEUE_NAME = "inference-requests"


def send_messages(count: int):
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_sender(QUEUE_NAME) as sender:
            # One batch instead of one round-trip per message - matters at 100.
            batch = sender.create_message_batch()
            for i in range(count):
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
                try:
                    batch.add_message(message)
                except ValueError:  # batch full - send it and start a new one
                    sender.send_messages(batch)
                    batch = sender.create_message_batch()
                    batch.add_message(message)
            sender.send_messages(batch)
            print(f"Sent {count} messages (req-0 .. req-{count - 1})")


def receive_and_settle(max_messages: int | None = None, delay_ms: int = 0,
                       crash_after: int | None = None):
    # Slide 10: peek-lock (default) - at-least-once delivery, must settle.
    in_flight = {}  # the message received but not yet settled, for the abort message

    def hard_exit(*_):
        # os._exit skips the client's clean shutdown - like a crashed or
        # killed process. The lock is NOT released; the message reappears
        # only once the lock expires.
        msg = in_flight.get("msg")
        if msg:
            print(f"\n  ABORTED before settling {msg.correlation_id} (seq {msg.sequence_number}) - "
                  f"locked until {msg.locked_until_utc:%H:%M:%S} UTC, then redelivered")
        else:
            print("\n  ABORTED (nothing in flight)")
        sys.stdout.flush()  # os._exit skips this too - output would be lost when piped
        os._exit(1)

    signal.signal(signal.SIGINT, hard_exit)

    received = 0
    with ServiceBusClient.from_connection_string(CONN_STR) as client:
        with client.get_queue_receiver(QUEUE_NAME) as receiver:
            while max_messages is None or received < max_messages:
                # delivery_count = PRIOR failed deliveries (0 on first receive);
                # it goes to the DLQ when it would exceed max delivery count.
                # One message per call (prefetch is 0 by default), so a
                # competing consumer only ever holds a lock on the message
                # it's actually working on.
                batch = receiver.receive_messages(max_message_count=1, max_wait_time=10)
                if not batch:
                    print("Queue empty (nothing received for 10s)")
                    break
                msg = batch[0]
                received += 1
                in_flight["msg"] = msg
                print(f"Received {msg.correlation_id or '(none)':>8}  seq={msg.sequence_number:<5} "
                      f"delivery_count={msg.delivery_count}  "
                      f"locked_until={msg.locked_until_utc:%H:%M:%S} UTC")

                if crash_after is not None and received >= crash_after:
                    hard_exit()

                try:
                    body = json.loads(str(msg))
                    # ... run_inference(body) would go here ...
                    if delay_ms:
                        time.sleep(delay_ms / 1000)  # the "processing" window to abort in
                    receiver.complete_message(msg)
                    print(f"  Completed {msg.correlation_id}: {body['prompt']}")
                except json.JSONDecodeError:
                    receiver.dead_letter_message(msg, reason="MalformedPayload")
                    print("  Dead-lettered: malformed payload")
                in_flight.pop("msg", None)
    print(f"Done - received {received} message(s)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command")
    p_send = sub.add_parser("send", help="send N messages")
    p_send.add_argument("--count", type=int, default=100)
    p_recv = sub.add_parser("receive", help="receive and settle messages one at a time")
    p_recv.add_argument("--max", type=int, help="stop after this many messages (default: drain the queue)")
    p_recv.add_argument("--delay-ms", type=int, default=0,
                        help="pause between receive and settle - Ctrl+C in this window to abort before settling")
    p_recv.add_argument("--crash-after", type=int, metavar="N",
                        help="hard-exit after receiving the Nth message, before settling it")
    args = parser.parse_args()

    if args.command == "send":
        send_messages(args.count)
    elif args.command == "receive":
        receive_and_settle(args.max, args.delay_ms, args.crash_after)
    else:
        send_messages(3)
        receive_and_settle()
