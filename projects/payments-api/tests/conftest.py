from __future__ import annotations

from collections.abc import Callable, Iterable, Iterator
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from payments_api.auth import READ_SCOPE, WRITE_SCOPE, issue_token
from payments_api.config import Settings
from payments_api.main import create_app

TEST_PAN = "4111111111111111"  # standard test card number, not a real card


class RecordingPublisher:
    """Test double for a message broker."""

    def __init__(self) -> None:
        self.events: list[tuple[int, str, dict[str, Any]]] = []
        self.fail = False

    def publish(self, event_id: int, event_type: str, payload: dict[str, Any]) -> None:
        if self.fail:
            raise ConnectionError("broker unavailable")
        self.events.append((event_id, event_type, payload))


@pytest.fixture
def settings(tmp_path: Any) -> Settings:
    return Settings(
        jwt_secret="test-jwt-secret-that-is-long-enough-1234",
        pan_hmac_key=b"test-pan-hmac-key-that-is-long-enough-1234",
        database_path=str(tmp_path / "payments.db"),
        outbox_relay_interval=0,
    )


@pytest.fixture
def publisher() -> RecordingPublisher:
    return RecordingPublisher()


@pytest.fixture
def app(settings: Settings, publisher: RecordingPublisher) -> FastAPI:
    return create_app(settings, publisher)


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


@pytest.fixture
def auth(settings: Settings) -> Callable[..., dict[str, str]]:
    def make(
        subject: str = "alice", scopes: Iterable[str] = (READ_SCOPE, WRITE_SCOPE)
    ) -> dict[str, str]:
        return {"Authorization": f"Bearer {issue_token(settings, subject, scopes)}"}

    return make


@pytest.fixture
def payment() -> Callable[..., dict[str, Any]]:
    def make(**overrides: Any) -> dict[str, Any]:
        body: dict[str, Any] = {
            "card_number": TEST_PAN,
            "amount": "25.50",
            "currency": "GBP",
            "merchant_id": "coffee-shop_01",
            "description": "Flat white",
        }
        body.update(overrides)
        return body

    return make
