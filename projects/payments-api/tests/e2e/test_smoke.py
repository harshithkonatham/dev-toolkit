"""End-to-end checks against a running deployment.

    BASE_URL=http://localhost:8000 JWT_SECRET=... uv run pytest tests/e2e

CI runs these against the built container and again inside a Kubernetes cluster.
They are skipped when BASE_URL is not set.
"""

import os
import uuid
from collections.abc import Iterator

import httpx
import pytest

from payments_api.auth import READ_SCOPE, WRITE_SCOPE, issue_token
from payments_api.config import Settings

BASE_URL = os.environ.get("BASE_URL", "")

pytestmark = [pytest.mark.e2e, pytest.mark.skipif(not BASE_URL, reason="BASE_URL not set")]


@pytest.fixture(scope="module")
def http() -> Iterator[httpx.Client]:
    with httpx.Client(base_url=BASE_URL, timeout=10) as client:
        yield client


@pytest.fixture(scope="module")
def headers() -> dict[str, str]:
    settings = Settings(jwt_secret=os.environ["JWT_SECRET"], pan_hmac_key=b"")
    subject = f"e2e-{uuid.uuid4()}"  # fresh user, so earlier runs don't interfere
    token = issue_token(settings, subject, [READ_SCOPE, WRITE_SCOPE])
    return {"Authorization": f"Bearer {token}"}


def test_service_is_healthy_and_ready(http: httpx.Client) -> None:
    assert http.get("/healthz").status_code == 200
    assert http.get("/readyz").status_code == 200


def test_requests_without_a_token_are_rejected(http: httpx.Client) -> None:
    assert http.get("/v1/transactions").status_code == 401


def test_payment_flow(http: httpx.Client, headers: dict[str, str]) -> None:
    payment = {
        "card_number": "4111111111111111",
        "amount": "12.34",
        "currency": "GBP",
        "merchant_id": "e2e-merchant",
    }
    idem = {**headers, "Idempotency-Key": f"e2e-{uuid.uuid4().hex[:16]}"}

    created = http.post("/v1/transactions", json=payment, headers=idem)
    assert created.status_code == 201, created.text
    txn = created.json()
    assert txn["card_last4"] == "1111"
    assert created.headers["Strict-Transport-Security"]

    replay = http.post("/v1/transactions", json=payment, headers=idem)
    assert replay.status_code == 200
    assert replay.json()["id"] == txn["id"]

    fetched = http.get(f"/v1/transactions/{txn['id']}", headers=headers)
    assert fetched.json() == txn
    assert [t["id"] for t in http.get("/v1/transactions", headers=headers).json()["items"]] == [
        txn["id"]
    ]


def test_metrics_are_exposed(http: httpx.Client) -> None:
    assert "transactions_created_total" in http.get("/metrics").text
