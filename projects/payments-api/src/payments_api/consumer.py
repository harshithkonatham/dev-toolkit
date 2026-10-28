"""Risk monitor: consumes ``transaction.created`` events and raises velocity alerts.

Run with ``python -m payments_api.consumer``. It shows the consumer side of the
outbox pattern:

* **Idempotent**: delivery is at-least-once, so each message ID is recorded in the
  same database transaction as its effects. A redelivered message is acked and skipped.
* **Validated**: messages are parsed into a strict model. Malformed ones are
  rejected without requeue and land in a dead-letter queue for inspection,
  instead of blocking the queue forever.
* **Acked after commit**: a crash before the commit means RabbitMQ redelivers.
"""

from __future__ import annotations

import logging
import os
import signal
import sqlite3
from collections.abc import Iterator
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import FrameType
from typing import Literal

import pika
from pika.adapters.blocking_connection import BlockingChannel
from pika.spec import Basic, BasicProperties
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from payments_api.config import ConfigError, read_broker_url
from payments_api.events import EXCHANGE
from payments_api.observability import configure_logging

logger = logging.getLogger("payments_api.consumer")

QUEUE = "risk-monitor"
DEAD_LETTER_EXCHANGE = "payments.dlx"
DEAD_LETTER_QUEUE = "risk-monitor.dlq"

# Velocity rule: this many approved payments by one customer inside the window
# is unusual enough for a human to look at.
VELOCITY_LIMIT = 3
VELOCITY_WINDOW = timedelta(minutes=1)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS processed_messages (
    message_id   TEXT PRIMARY KEY,
    processed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS seen_transactions (
    transaction_id TEXT PRIMARY KEY,
    owner          TEXT NOT NULL,
    status         TEXT NOT NULL,
    seen_at        TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_seen_owner_time ON seen_transactions (owner, seen_at);
CREATE TABLE IF NOT EXISTS risk_alerts (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    owner          TEXT NOT NULL,
    transaction_id TEXT NOT NULL,
    reason         TEXT NOT NULL,
    created_at     TEXT NOT NULL
);
"""


class TransactionCreated(BaseModel):
    """The event body. Card numbers are never part of it, only the last four digits."""

    model_config = ConfigDict(extra="forbid", frozen=True)

    transaction_id: str = Field(min_length=1, max_length=64)
    owner: str = Field(min_length=1, max_length=128)
    amount: Decimal = Field(gt=0)
    currency: str = Field(pattern=r"^[A-Z]{3}$")
    merchant_id: str = Field(min_length=1, max_length=64)
    status: Literal["approved", "declined"]
    card_last4: str = Field(pattern=r"^\d{4}$")


Outcome = Literal["processed", "duplicate", "alerted"]


@dataclass(frozen=True)
class Alert:
    owner: str
    transaction_id: str
    reason: str


class RiskStore:
    def __init__(self, path: str) -> None:
        self._path = path
        with self._connect() as conn:
            conn.executescript(_SCHEMA)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        with closing(sqlite3.connect(self._path, timeout=5, isolation_level=None)) as conn:
            conn.row_factory = sqlite3.Row
            yield conn

    def handle(self, message_id: str, event: TransactionCreated, now: datetime) -> Outcome:
        """Apply one event exactly once. Returns what happened."""
        with self._connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                outcome = self._apply(conn, message_id, event, now)
            except BaseException:
                conn.execute("ROLLBACK")
                raise
            conn.execute("COMMIT")
        return outcome

    def _apply(
        self, conn: sqlite3.Connection, message_id: str, event: TransactionCreated, now: datetime
    ) -> Outcome:
        if conn.execute(
            "SELECT 1 FROM processed_messages WHERE message_id = ?", (message_id,)
        ).fetchone():
            return "duplicate"
        conn.execute(
            "INSERT INTO processed_messages (message_id, processed_at) VALUES (?, ?)",
            (message_id, now.isoformat()),
        )
        conn.execute(
            "INSERT OR IGNORE INTO seen_transactions (transaction_id, owner, status, seen_at) "
            "VALUES (?, ?, ?, ?)",
            (event.transaction_id, event.owner, event.status, now.isoformat()),
        )
        if event.status != "approved":
            return "processed"
        row = conn.execute(
            "SELECT count(*) FROM seen_transactions "
            "WHERE owner = ? AND status = 'approved' AND seen_at >= ?",
            (event.owner, (now - VELOCITY_WINDOW).isoformat()),
        ).fetchone()
        if row[0] < VELOCITY_LIMIT:
            return "processed"
        conn.execute(
            "INSERT INTO risk_alerts (owner, transaction_id, reason, created_at) "
            "VALUES (?, ?, ?, ?)",
            (event.owner, event.transaction_id, "velocity", now.isoformat()),
        )
        logger.warning(
            "risk alert",
            extra={"owner": event.owner, "transaction_id": event.transaction_id},
        )
        return "alerted"

    def alerts(self) -> list[Alert]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT owner, transaction_id, reason FROM risk_alerts ORDER BY id"
            ).fetchall()
        return [Alert(r["owner"], r["transaction_id"], r["reason"]) for r in rows]


def declare_topology(channel: BlockingChannel) -> None:
    """Create the exchange, queue, binding and dead-letter queue (safe to repeat)."""
    channel.exchange_declare(EXCHANGE, exchange_type="topic", durable=True)
    channel.exchange_declare(DEAD_LETTER_EXCHANGE, exchange_type="fanout", durable=True)
    channel.queue_declare(DEAD_LETTER_QUEUE, durable=True)
    channel.queue_bind(DEAD_LETTER_QUEUE, DEAD_LETTER_EXCHANGE)
    channel.queue_declare(
        QUEUE,
        durable=True,
        arguments={"x-dead-letter-exchange": DEAD_LETTER_EXCHANGE, "x-queue-type": "quorum"},
    )
    channel.queue_bind(QUEUE, EXCHANGE, routing_key="transaction.created")


def on_message(
    store: RiskStore,
    channel: BlockingChannel,
    method: Basic.Deliver,
    properties: BasicProperties,
    body: bytes,
) -> Outcome | None:
    """Process one delivery and ack or reject it. Returns the outcome, or None if rejected."""
    message_id = properties.message_id
    try:
        if not message_id:
            raise ValueError("message has no message_id")
        event = TransactionCreated.model_validate_json(body)
    except (ValueError, ValidationError):
        # Never log the body: a malformed message could contain anything.
        logger.error("rejected malformed message", extra={"message_id": message_id})
        channel.basic_nack(method.delivery_tag, requeue=False)  # goes to the DLQ
        return None
    outcome = store.handle(message_id, event, datetime.now(UTC))
    channel.basic_ack(method.delivery_tag)
    return outcome


def run(url: str, db_path: str) -> None:  # pragma: no cover - exercised by the e2e stack
    store = RiskStore(db_path)
    connection = pika.BlockingConnection(pika.URLParameters(url))
    channel = connection.channel()
    declare_topology(channel)
    channel.basic_qos(prefetch_count=20)
    channel.basic_consume(QUEUE, lambda ch, m, p, b: on_message(store, ch, m, p, b), auto_ack=False)

    def stop(signum: int, _frame: FrameType | None) -> None:
        logger.info("stopping", extra={"signal": signum})
        channel.stop_consuming()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    logger.info("consuming", extra={"queue": QUEUE})
    try:
        channel.start_consuming()
    finally:
        connection.close()


def main() -> int:  # pragma: no cover - thin wrapper around run()
    configure_logging(os.environ.get("LOG_LEVEL", "INFO").upper())
    try:
        url = read_broker_url()
    except ConfigError as exc:
        logger.error("configuration error", extra={"error": str(exc)})
        return 2
    run(url, os.environ.get("RISK_DATABASE_PATH", "risk.db"))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
