import time
from collections.abc import Callable
from typing import Any

from fastapi import FastAPI
from fastapi.testclient import TestClient

from payments_api.config import Settings
from payments_api.events import LogPublisher, relay_outbox
from payments_api.main import create_app

from ..conftest import TEST_PAN, RecordingPublisher

Auth = Callable[..., dict[str, str]]
Payment = Callable[..., dict[str, Any]]


def test_each_transaction_emits_one_event_without_card_data(
    app: FastAPI,
    client: TestClient,
    auth: Auth,
    payment: Payment,
    publisher: RecordingPublisher,
) -> None:
    headers = {**auth(), "Idempotency-Key": "order-12345678"}  # gitleaks:allow (test fixture)
    txn = client.post("/v1/transactions", json=payment(), headers=headers).json()
    client.post("/v1/transactions", json=payment(), headers=headers)  # replay: no new event

    assert relay_outbox(app.state.repo, publisher) == 1
    [(_, event_type, event)] = publisher.events
    assert event_type == "transaction.created"
    assert event["transaction_id"] == txn["id"]
    assert event["amount"] == "25.50"
    assert TEST_PAN not in str(event)

    assert relay_outbox(app.state.repo, publisher) == 0  # already published


def test_failed_publish_is_retried_in_order(
    app: FastAPI,
    client: TestClient,
    auth: Auth,
    payment: Payment,
    publisher: RecordingPublisher,
) -> None:
    for amount in ("1.00", "2.00"):
        client.post("/v1/transactions", json=payment(amount=amount), headers=auth())

    publisher.fail = True
    assert relay_outbox(app.state.repo, publisher) == 0

    publisher.fail = False
    assert relay_outbox(app.state.repo, publisher) == 2
    assert [e[2]["amount"] for e in publisher.events] == ["1.00", "2.00"]


def test_background_relay_publishes_automatically(
    settings: Settings, auth: Auth, payment: Payment
) -> None:
    publisher = RecordingPublisher()
    settings = Settings(**{**vars(settings), "outbox_relay_interval": 0.05})
    with TestClient(create_app(settings, publisher)) as client:
        client.post("/v1/transactions", json=payment(), headers=auth())
        deadline = time.monotonic() + 3
        while not publisher.events and time.monotonic() < deadline:
            time.sleep(0.05)
    assert len(publisher.events) == 1


def test_log_publisher_does_not_raise() -> None:
    LogPublisher().publish(1, "transaction.created", {"transaction_id": "x"})
