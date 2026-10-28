"""SQLite storage for transactions, plus a transactional outbox for events.

* Every query is parameterised; no SQL is built from user input.
* Money is stored as integer minor units (pence, cents, yen), never floats.
* A transaction and its ``transaction.created`` event are written in the same
  database transaction (the outbox pattern), so an event is never lost or sent
  for a payment that was rolled back. A relay publishes events afterwards.
"""

from __future__ import annotations

import json
import sqlite3
import uuid
from collections.abc import Iterator
from contextlib import closing, contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from typing import Any

from payments_api.models import Transaction

# ISO 4217 minor-unit exponents for the supported currencies.
MINOR_UNIT_EXPONENT = {"JPY": 0}
DEFAULT_EXPONENT = 2

_SCHEMA = """
CREATE TABLE IF NOT EXISTS transactions (
    id               TEXT PRIMARY KEY,
    owner            TEXT NOT NULL,
    card_fingerprint TEXT NOT NULL,
    card_last4       TEXT NOT NULL,
    amount_minor     INTEGER NOT NULL CHECK (amount_minor > 0),
    currency         TEXT NOT NULL,
    merchant_id      TEXT NOT NULL,
    description      TEXT,
    status           TEXT NOT NULL,
    created_at       TEXT NOT NULL,
    idempotency_key  TEXT,
    request_hash     TEXT,
    UNIQUE (owner, idempotency_key)
);
CREATE INDEX IF NOT EXISTS ix_transactions_owner_created
    ON transactions (owner, created_at DESC);
CREATE TABLE IF NOT EXISTS outbox (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type   TEXT NOT NULL,
    payload      TEXT NOT NULL,
    created_at   TEXT NOT NULL,
    published_at TEXT
);
CREATE INDEX IF NOT EXISTS ix_outbox_pending ON outbox (published_at, id);
"""

# Queries are complete string literals; values are always bound as ? parameters.
_SELECT_BY_IDEMPOTENCY_KEY = """
SELECT id, card_last4, amount_minor, currency, merchant_id, description, status, created_at,
       request_hash
FROM transactions WHERE owner = ? AND idempotency_key = ?
"""
_SELECT_BY_ID = """
SELECT id, card_last4, amount_minor, currency, merchant_id, description, status, created_at
FROM transactions WHERE id = ?
"""
_SELECT_OWNED = """
SELECT id, card_last4, amount_minor, currency, merchant_id, description, status, created_at
FROM transactions WHERE owner = ? AND id = ?
"""
_LIST_OWNED = """
SELECT id, card_last4, amount_minor, currency, merchant_id, description, status, created_at
FROM transactions WHERE owner = ? ORDER BY created_at DESC, id LIMIT ?
"""


class IdempotencyConflictError(Exception):
    """The idempotency key was already used with a different request body."""


@dataclass(frozen=True)
class NewTransaction:
    owner: str
    card_fingerprint: str
    card_last4: str
    amount: Decimal
    currency: str
    merchant_id: str
    description: str | None
    status: str
    idempotency_key: str | None
    request_hash: str


@dataclass(frozen=True)
class OutboxEvent:
    id: int
    event_type: str
    payload: dict[str, Any]


def to_minor(amount: Decimal, currency: str) -> int:
    exponent = MINOR_UNIT_EXPONENT.get(currency, DEFAULT_EXPONENT)
    return int(amount.scaleb(exponent))


def from_minor(amount_minor: int, currency: str) -> Decimal:
    exponent = MINOR_UNIT_EXPONENT.get(currency, DEFAULT_EXPONENT)
    return Decimal(amount_minor).scaleb(-exponent)


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _row_to_transaction(row: sqlite3.Row) -> Transaction:
    return Transaction(
        id=row["id"],
        card_last4=row["card_last4"],
        amount=from_minor(row["amount_minor"], row["currency"]),
        currency=row["currency"],
        merchant_id=row["merchant_id"],
        description=row["description"],
        status=row["status"],
        created_at=datetime.fromisoformat(row["created_at"]),
    )


class Repository:
    def __init__(self, path: str) -> None:
        self._path = path
        with self._connect() as conn:
            conn.executescript(_SCHEMA)

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        # Autocommit mode; write methods open explicit transactions.
        with closing(sqlite3.connect(self._path, timeout=5, isolation_level=None)) as conn:
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA foreign_keys=ON")
            yield conn

    @contextmanager
    def _write(self) -> Iterator[sqlite3.Connection]:
        with self._connect() as conn:
            conn.execute("BEGIN IMMEDIATE")
            try:
                yield conn
            except BaseException:
                conn.execute("ROLLBACK")
                raise
            conn.execute("COMMIT")

    def ping(self) -> None:
        with self._connect() as conn:
            conn.execute("SELECT 1").fetchone()

    def create(self, new: NewTransaction) -> tuple[Transaction, bool]:
        """Insert a transaction. Returns ``(transaction, created)``.

        Repeating a request with the same idempotency key returns the original
        transaction with ``created=False`` instead of charging twice.
        """
        with self._write() as conn:
            if new.idempotency_key is not None:
                existing = conn.execute(
                    _SELECT_BY_IDEMPOTENCY_KEY, (new.owner, new.idempotency_key)
                ).fetchone()
                if existing is not None:
                    if existing["request_hash"] != new.request_hash:
                        raise IdempotencyConflictError
                    return _row_to_transaction(existing), False

            txn_id = str(uuid.uuid4())
            created_at = _now()
            conn.execute(
                "INSERT INTO transactions (id, owner, card_fingerprint, card_last4, amount_minor,"
                " currency, merchant_id, description, status, created_at, idempotency_key,"
                " request_hash) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    txn_id,
                    new.owner,
                    new.card_fingerprint,
                    new.card_last4,
                    to_minor(new.amount, new.currency),
                    new.currency,
                    new.merchant_id,
                    new.description,
                    new.status,
                    created_at,
                    new.idempotency_key,
                    new.request_hash,
                ),
            )
            event = {
                "transaction_id": txn_id,
                "owner": new.owner,
                "amount": str(new.amount),
                "currency": new.currency,
                "merchant_id": new.merchant_id,
                "status": new.status,
                "card_last4": new.card_last4,
            }
            conn.execute(
                "INSERT INTO outbox (event_type, payload, created_at) VALUES (?, ?, ?)",
                ("transaction.created", json.dumps(event), created_at),
            )
            row = conn.execute(_SELECT_BY_ID, (txn_id,)).fetchone()
        return _row_to_transaction(row), True

    def get(self, owner: str, txn_id: str) -> Transaction | None:
        with self._connect() as conn:
            row = conn.execute(_SELECT_OWNED, (owner, txn_id)).fetchone()
        return _row_to_transaction(row) if row else None

    def list_for(self, owner: str, limit: int) -> list[Transaction]:
        with self._connect() as conn:
            rows = conn.execute(_LIST_OWNED, (owner, limit)).fetchall()
        return [_row_to_transaction(row) for row in rows]

    def pending_events(self, limit: int) -> list[OutboxEvent]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT id, event_type, payload FROM outbox "
                "WHERE published_at IS NULL ORDER BY id LIMIT ?",
                (limit,),
            ).fetchall()
        return [OutboxEvent(r["id"], r["event_type"], json.loads(r["payload"])) for r in rows]

    def mark_published(self, event_id: int) -> None:
        with self._write() as conn:
            conn.execute("UPDATE outbox SET published_at = ? WHERE id = ?", (_now(), event_id))
