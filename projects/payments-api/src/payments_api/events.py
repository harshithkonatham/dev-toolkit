"""Outbox relay: moves stored events onto a message broker.

``Publisher`` is the integration point. ``LogPublisher`` writes events to the log
(the default, handy for local runs); ``RabbitMQPublisher`` sends them to a durable
RabbitMQ topic exchange. Delivery is at-least-once, so consumers de-duplicate on
the message ID (the outbox row ID).
"""

from __future__ import annotations

import json
import logging
import time
from typing import TYPE_CHECKING, Any, Protocol

import pika
from pika.adapters.blocking_connection import BlockingChannel

from payments_api.db import Repository

if TYPE_CHECKING:
    from payments_api.config import Settings

logger = logging.getLogger("payments_api.events")

EXCHANGE = "payments.events"


class Publisher(Protocol):
    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None: ...


class LogPublisher:
    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None:
        logger.info(
            "event published",
            extra={"event_id": event_id, "event_type": event_type, "payload": payload},
        )


class RabbitMQPublisher:
    """Publishes each event as a persistent message and waits for the broker to confirm it.

    The outbox row is only marked published after the confirm, so a broker crash
    can cause a re-send but never a lost event. The connection is opened on first
    use and dropped after any error, so the next relay run reconnects cleanly.
    The relay calls this from one worker thread at a time, which is what pika's
    blocking connection requires.
    """

    def __init__(self, url: str, exchange: str = EXCHANGE) -> None:
        self._params = pika.URLParameters(url)
        self._params.heartbeat = 30
        self._params.blocked_connection_timeout = 10
        self._exchange = exchange
        self._connection: pika.BlockingConnection | None = None
        self._channel: BlockingChannel | None = None

    def _ensure_channel(self) -> BlockingChannel:
        if self._channel is None or self._channel.is_closed:
            self.close()
            self._connection = pika.BlockingConnection(self._params)
            channel = self._connection.channel()
            channel.exchange_declare(self._exchange, exchange_type="topic", durable=True)
            channel.confirm_delivery()
            self._channel = channel
        return self._channel

    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None:
        try:
            self._ensure_channel().basic_publish(
                exchange=self._exchange,
                routing_key=event_type,
                body=json.dumps(payload, separators=(",", ":")).encode(),
                properties=pika.BasicProperties(
                    content_type="application/json",
                    delivery_mode=pika.DeliveryMode.Persistent,
                    message_id=str(event_id),
                    type=event_type,
                    timestamp=int(time.time()),
                ),
                mandatory=True,  # error if no queue is bound, instead of dropping it
            )
        except Exception:
            self.close()
            raise

    def close(self) -> None:
        connection, self._connection, self._channel = self._connection, None, None
        if connection is not None and connection.is_open:
            try:
                connection.close()
            except Exception:  # already broken; nothing more to clean up
                logger.debug("error closing broker connection", exc_info=True)


def publisher_from_settings(settings: Settings) -> Publisher:
    if settings.event_broker == "rabbitmq" and settings.rabbitmq_url:
        return RabbitMQPublisher(settings.rabbitmq_url)
    return LogPublisher()


def relay_outbox(repo: Repository, publisher: Publisher, batch_size: int = 100) -> int:
    """Publish pending events in order. Returns how many were published.

    Stops at the first failure so ordering is kept; the event is retried next run.
    """
    published = 0
    for event in repo.pending_events(batch_size):
        try:
            publisher.publish(event.id, event.event_type, event.payload)
        except Exception:
            logger.exception("event publish failed", extra={"event_id": event.id})
            break
        repo.mark_published(event.id)
        published += 1
    return published
