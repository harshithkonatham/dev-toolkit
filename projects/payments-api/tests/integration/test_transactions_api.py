import uuid
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient

from payments_api.auth import READ_SCOPE, WRITE_SCOPE

Auth = Callable[..., dict[str, str]]
Payment = Callable[..., dict[str, Any]]


def test_health_and_readiness(client: TestClient) -> None:
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/readyz").json() == {"status": "ready"}


def test_create_transaction(client: TestClient, auth: Auth, payment: Payment) -> None:
    response = client.post("/v1/transactions", json=payment(), headers=auth())

    assert response.status_code == 201
    body = response.json()
    assert response.headers["Location"] == f"/v1/transactions/{body['id']}"
    assert body["card_last4"] == "1111"
    assert body["amount"] == "25.50"  # money is returned as a string, never a float
    assert body["currency"] == "GBP"
    assert body["status"] == "approved"
    assert "card_number" not in body
    assert "4111111111111111" not in response.text


def test_payment_over_the_limit_is_declined(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    response = client.post("/v1/transactions", json=payment(amount="10000.01"), headers=auth())
    assert response.status_code == 201
    assert response.json()["status"] == "declined"


def test_get_and_list_own_transactions(client: TestClient, auth: Auth, payment: Payment) -> None:
    created = [
        client.post("/v1/transactions", json=payment(amount=str(n)), headers=auth()).json()
        for n in (1, 2, 3)
    ]

    fetched = client.get(f"/v1/transactions/{created[0]['id']}", headers=auth())
    assert fetched.status_code == 200
    assert fetched.json() == created[0]

    listed = client.get("/v1/transactions", params={"limit": 2}, headers=auth())
    assert listed.status_code == 200
    assert len(listed.json()["items"]) == 2


def test_users_cannot_see_each_others_transactions(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    alice_txn = client.post("/v1/transactions", json=payment(), headers=auth("alice")).json()

    # Same response as an ID that doesn't exist, so IDs can't be probed.
    response = client.get(f"/v1/transactions/{alice_txn['id']}", headers=auth("mallory"))
    assert response.status_code == 404
    assert client.get("/v1/transactions", headers=auth("mallory")).json() == {"items": []}


def test_unknown_and_malformed_ids(client: TestClient, auth: Auth) -> None:
    assert client.get(f"/v1/transactions/{uuid.uuid4()}", headers=auth()).status_code == 404
    assert client.get("/v1/transactions/not-a-uuid", headers=auth()).status_code == 422


def test_list_limit_is_bounded(client: TestClient, auth: Auth) -> None:
    assert client.get("/v1/transactions?limit=0", headers=auth()).status_code == 422
    assert client.get("/v1/transactions?limit=101", headers=auth()).status_code == 422


def test_missing_or_invalid_token_is_401(client: TestClient, payment: Payment) -> None:
    for headers in ({}, {"Authorization": "Bearer not-a-jwt"}, {"Authorization": "Basic abc"}):
        response = client.post("/v1/transactions", json=payment(), headers=headers)
        assert response.status_code == 401
        assert response.headers["WWW-Authenticate"] == "Bearer"


def test_missing_scope_is_403(client: TestClient, auth: Auth, payment: Payment) -> None:
    read_only = auth(scopes=[READ_SCOPE])
    write_only = auth(scopes=[WRITE_SCOPE])
    assert client.post("/v1/transactions", json=payment(), headers=read_only).status_code == 403
    assert client.get("/v1/transactions", headers=write_only).status_code == 403


def test_idempotent_retry_returns_the_original(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    headers = {**auth(), "Idempotency-Key": "order-12345678"}
    first = client.post("/v1/transactions", json=payment(), headers=headers)
    retry = client.post("/v1/transactions", json=payment(), headers=headers)

    assert first.status_code == 201
    assert retry.status_code == 200
    assert retry.headers["Idempotent-Replayed"] == "true"
    assert retry.json() == first.json()
    assert len(client.get("/v1/transactions", headers=auth()).json()["items"]) == 1


def test_reusing_a_key_with_a_different_body_is_409(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    headers = {**auth(), "Idempotency-Key": "order-12345678"}
    client.post("/v1/transactions", json=payment(), headers=headers)
    conflict = client.post("/v1/transactions", json=payment(amount="99.00"), headers=headers)
    assert conflict.status_code == 409


def test_idempotency_keys_are_per_user(client: TestClient, auth: Auth, payment: Payment) -> None:
    key = {"Idempotency-Key": "shared-key-0001"}
    alice = client.post("/v1/transactions", json=payment(), headers={**auth("alice"), **key})
    bob = client.post("/v1/transactions", json=payment(), headers={**auth("bob"), **key})
    assert alice.status_code == bob.status_code == 201
    assert alice.json()["id"] != bob.json()["id"]


def test_malformed_idempotency_key_is_rejected(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    headers = {**auth(), "Idempotency-Key": "bad key!"}
    assert client.post("/v1/transactions", json=payment(), headers=headers).status_code == 422


def test_metrics_count_requests_and_transactions(
    client: TestClient, auth: Auth, payment: Payment
) -> None:
    client.post("/v1/transactions", json=payment(), headers=auth())
    metrics = client.get("/metrics").text
    assert 'transactions_created_total{currency="GBP",status="approved"} 1.0' in metrics
    assert 'route="/v1/transactions",status="201"' in metrics
