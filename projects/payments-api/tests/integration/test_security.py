"""Security behaviour, tested through the HTTP API."""

import io
import logging
import sqlite3
from collections.abc import Callable, Iterator
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from payments_api.config import Settings
from payments_api.main import create_app
from payments_api.observability import SECURITY_HEADERS, JsonFormatter

from ..conftest import TEST_PAN

Auth = Callable[..., dict[str, str]]
Payment = Callable[..., dict[str, Any]]


@pytest.fixture
def log_output() -> Iterator[io.StringIO]:
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(JsonFormatter())
    logging.getLogger().addHandler(handler)
    yield stream
    logging.getLogger().removeHandler(handler)


def test_security_headers_on_every_response(client: TestClient) -> None:
    for path in ("/healthz", "/v1/transactions", "/does-not-exist"):
        response = client.get(path)
        for name, value in SECURITY_HEADERS.items():
            assert response.headers[name] == value


def test_validation_errors_never_echo_the_card_number(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    # A valid card with an invalid amount: FastAPI's default error would echo the body.
    response = client.post("/v1/transactions", json=payment(amount="-1"), headers=auth())
    assert response.status_code == 422
    assert TEST_PAN not in response.text
    assert response.json()["detail"][0]["loc"] == ["body", "amount"]

    bad_card = "4111111111111112"
    response = client.post("/v1/transactions", json=payment(card_number=bad_card), headers=auth())
    assert response.status_code == 422
    assert bad_card not in response.text


def test_card_number_never_reaches_the_logs(
    client: TestClient, auth: Auth, payment: Payment, log_output: io.StringIO
) -> None:
    client.post("/v1/transactions", json=payment(), headers=auth())
    client.post("/v1/transactions", json=payment(amount="-1"), headers=auth())
    logs = log_output.getvalue()
    assert "transaction created" in logs
    assert "************1111" in logs
    assert TEST_PAN not in logs


def test_sql_is_treated_as_data(client: TestClient, auth: Auth, payment: Payment) -> None:
    injection = "'); DROP TABLE transactions; --"
    response = client.post("/v1/transactions", json=payment(description=injection), headers=auth())
    assert response.status_code == 201
    assert response.json()["description"] == injection
    assert len(client.get("/v1/transactions", headers=auth()).json()["items"]) == 1


def test_oversized_body_is_rejected_before_parsing(client: TestClient, auth: Auth) -> None:
    response = client.post(
        "/v1/transactions",
        content=b"{" + b" " * 20_000 + b"}",
        headers={**auth(), "Content-Type": "application/json"},
    )
    assert response.status_code == 413
    assert "X-Request-ID" in response.headers


def test_oversized_streamed_body_without_length_is_rejected(app: FastAPI) -> None:
    client = TestClient(app)

    def chunks() -> Iterator[bytes]:
        for _ in range(20):
            yield b" " * 1024

    response = client.post("/v1/transactions", content=chunks())
    assert response.status_code == 413


def test_request_ids_are_echoed_only_when_safe(client: TestClient) -> None:
    assert client.get("/healthz", headers={"X-Request-ID": "abc-12345678"}).headers[
        "X-Request-ID"
    ] == ("abc-12345678")
    generated = client.get("/healthz", headers={"X-Request-ID": "bad id {injected}"})
    assert generated.headers["X-Request-ID"] != "bad id {injected}"
    assert len(generated.headers["X-Request-ID"]) == 36


def test_api_docs_are_off_by_default(client: TestClient) -> None:
    assert client.get("/docs").status_code == 404
    assert client.get("/openapi.json").status_code == 404


def test_api_docs_can_be_enabled(settings: Settings) -> None:
    settings = Settings(**{**vars(settings), "enable_docs": True})
    with TestClient(create_app(settings)) as client:
        response = client.get("/docs")
        assert response.status_code == 200
        assert "Content-Security-Policy" not in response.headers


def test_unexpected_errors_do_not_leak_details(
    app: FastAPI, client: TestClient, auth: Auth, monkeypatch: pytest.MonkeyPatch
) -> None:
    def boom(*_: object) -> None:
        raise RuntimeError("secret internal detail")

    monkeypatch.setattr(app.state.repo, "list_for", boom)
    response = client.get("/v1/transactions", headers=auth())
    assert response.status_code == 500
    assert response.json() == {"detail": "internal server error"}


def test_readiness_fails_when_the_database_is_down(
    app: FastAPI, client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    def down() -> None:
        raise sqlite3.OperationalError("disk I/O error")

    monkeypatch.setattr(app.state.repo, "ping", down)
    assert client.get("/readyz").status_code == 503
