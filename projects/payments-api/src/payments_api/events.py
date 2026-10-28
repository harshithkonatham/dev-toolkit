"""Outbox relay: moves stored events onto a message broker.

``Publisher`` is the integration point. The default ``LogPublisher`` writes events
to the log; a Kafka, SQS or RabbitMQ publisher would implement the same method.
Delivery is at-least-once, so consumers should de-duplicate on ``event_id``.
"""

from __future__ import annotations

import logging
from typing import Any, Protocol

from payments_api.db import Repository

logger = logging.getLogger("payments_api.events")


class Publisher(Protocol):
    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None: ...


class LogPublisher:
    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None:
        logger.info(
            "event published",
            extra={"event_id": event_id, "event_type": event_type, "payload": payload},
        )


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
