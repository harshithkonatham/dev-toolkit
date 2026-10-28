from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from payments_api import consumer

NOW = datetime(2026, 10, 1, 12, 0, tzinfo=UTC)


def event(**overrides: Any) -> consumer.TransactionCreated:
    body: dict[str, Any] = {
        "transaction_id": "t-1",
        "owner": "alice",
        "amount": "25.50",
        "currency": "GBP",
        "merchant_id": "coffee-shop_01",
        "status": "approved",
        "card_last4": "1111",
    }
    body.update(overrides)
    return consumer.TransactionCreated.model_validate(body)


@pytest.fixture
def store(tmp_path: Path) -> consumer.RiskStore:
    return consumer.RiskStore(str(tmp_path / "risk.db"))


class FakeChannel:
    def __init__(self) -> None:
        self.acked: list[int] = []
        self.nacked: list[tuple[int, bool]] = []

    def basic_ack(self, tag: int) -> None:
        self.acked.append(tag)

    def basic_nack(self, tag: int, requeue: bool) -> None:
        self.nacked.append((tag, requeue))


def deliver(store: consumer.RiskStore, body: bytes, message_id: str | None = "1") -> Any:
    channel = FakeChannel()
    outcome = consumer.on_message(
        store,
        channel,  # type: ignore[arg-type]
        SimpleNamespace(delivery_tag=7),  # type: ignore[arg-type]
        SimpleNamespace(message_id=message_id),  # type: ignore[arg-type]
        body,
    )
    return outcome, channel


def test_redelivered_message_is_applied_once(store: consumer.RiskStore) -> None:
    assert store.handle("42", event(), NOW) == "processed"
    assert store.handle("42", event(), NOW) == "duplicate"


def test_velocity_alert_on_third_approved_payment_in_a_minute(store: consumer.RiskStore) -> None:
    outcomes = [
        store.handle(str(i), event(transaction_id=f"t-{i}"), NOW + timedelta(seconds=10 * i))
        for i in range(3)
    ]
    assert outcomes == ["processed", "processed", "alerted"]
    assert store.alerts() == [consumer.Alert("alice", "t-2", "velocity")]


def test_payments_spread_out_do_not_alert(store: consumer.RiskStore) -> None:
    for i in range(4):
        outcome = store.handle(str(i), event(transaction_id=f"t-{i}"), NOW + timedelta(minutes=i))
        assert outcome == "processed"
    assert store.alerts() == []


def test_declined_payments_do_not_count(store: consumer.RiskStore) -> None:
    for i in range(3):
        store.handle(str(i), event(transaction_id=f"t-{i}", status="declined"), NOW)
    assert store.alerts() == []


def test_other_customers_do_not_count(store: consumer.RiskStore) -> None:
    for i, owner in enumerate(["alice", "bob", "carol"]):
        store.handle(str(i), event(transaction_id=f"t-{i}", owner=owner), NOW)
    assert store.alerts() == []


def test_failed_apply_rolls_back(
    store: consumer.RiskStore, monkeypatch: pytest.MonkeyPatch
) -> None:
    def boom(*_: Any) -> None:
        raise RuntimeError("disk full")

    monkeypatch.setattr(store, "_apply", boom)
    with pytest.raises(RuntimeError):
        store.handle("9", event(), NOW)
    monkeypatch.undo()
    # Nothing was recorded, so the redelivery is processed normally.
    assert store.handle("9", event(), NOW) == "processed"


def test_valid_message_is_acked(store: consumer.RiskStore) -> None:
    outcome, channel = deliver(store, event().model_dump_json().encode())
    assert outcome == "processed"
    assert channel.acked == [7]
    assert channel.nacked == []


@pytest.mark.parametrize(
    "body",
    [
        b"not json",
        b'{"transaction_id": "t-1"}',
        event().model_dump_json().replace("1111", "4111111111111111").encode(),
        event().model_dump_json().replace('"GBP"', '"gbp"').encode(),
        event().model_dump_json()[:-1].encode() + b', "card_number": "4111111111111111"}',
    ],
)
def test_malformed_message_goes_to_dead_letter_queue(
    store: consumer.RiskStore, body: bytes
) -> None:
    outcome, channel = deliver(store, body)
    assert outcome is None
    assert channel.nacked == [(7, False)]
    assert channel.acked == []


def test_message_without_id_is_rejected(store: consumer.RiskStore) -> None:
    outcome, channel = deliver(store, event().model_dump_json().encode(), message_id=None)
    assert outcome is None
    assert channel.nacked == [(7, False)]
