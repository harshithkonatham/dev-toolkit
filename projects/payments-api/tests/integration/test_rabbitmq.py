"""Runs the outbox relay and the risk consumer against a real RabbitMQ broker.

Skipped unless RABBITMQ_URL is set. CI starts a broker as a service container;
locally: ``docker compose up -d rabbitmq`` and
``RABBITMQ_URL=amqp://payments:payments-local-only@localhost:5672/%2F``.
"""

import os
import time
import uuid
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pika
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from payments_api import consumer, events
from payments_api.events import relay_outbox

pytestmark = pytest.mark.rabbitmq

URL = os.environ.get("RABBITMQ_URL", "")
if not URL:
    pytest.skip("RABBITMQ_URL not set", allow_module_level=True)


@pytest.fixture
def channel() -> Iterator[Any]:
    connection = pika.BlockingConnection(pika.URLParameters(URL))
    ch = connection.channel()
    consumer.declare_topology(ch)
    ch.queue_purge(consumer.QUEUE)
    ch.queue_purge(consumer.DEAD_LETTER_QUEUE)
    yield ch
    connection.close()


def drain(ch: Any, queue: str, expected: int, timeout: float = 10) -> list[tuple[Any, Any, bytes]]:
    messages: list[tuple[Any, Any, bytes]] = []
    deadline = time.monotonic() + timeout
    while len(messages) < expected and time.monotonic() < deadline:
        method, props, body = ch.basic_get(queue, auto_ack=False)
        if method is None:
            time.sleep(0.1)
            continue
        messages.append((method, props, body))
    return messages


def test_payment_event_reaches_consumer_and_triggers_alert(
    channel: Any,
    app: FastAPI,
    client: TestClient,
    auth: Callable[..., dict[str, str]],
    payment: Callable[..., dict[str, Any]],
    tmp_path: Path,
) -> None:
    owner = f"user-{uuid.uuid4().hex[:8]}"
    for _ in range(3):
        client.post("/v1/transactions", json=payment(), headers=auth(subject=owner))

    publisher = events.RabbitMQPublisher(URL)
    try:
        assert relay_outbox(app.state.repo, publisher) == 3
    finally:
        publisher.close()

    store = consumer.RiskStore(str(tmp_path / "risk.db"))
    outcomes = [
        consumer.on_message(store, channel, method, props, body)
        for method, props, body in drain(channel, consumer.QUEUE, 3)
    ]
    assert outcomes == ["processed", "processed", "alerted"]
    assert store.alerts()[0].owner == owner


def test_malformed_message_is_dead_lettered(channel: Any, tmp_path: Path) -> None:
    channel.basic_publish(
        events.EXCHANGE,
        "transaction.created",
        b'{"card_number": "4111111111111111"}',
        pika.BasicProperties(message_id="bad-1", delivery_mode=2),
    )
    [(method, props, body)] = drain(channel, consumer.QUEUE, 1)
    store = consumer.RiskStore(str(tmp_path / "risk.db"))

    assert consumer.on_message(store, channel, method, props, body) is None

    dead = drain(channel, consumer.DEAD_LETTER_QUEUE, 1)
    assert len(dead) == 1
    channel.basic_ack(dead[0][0].delivery_tag)
