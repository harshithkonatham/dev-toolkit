"""FastAPI application. Start with ``uvicorn --factory payments_api.main:create_app``."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import sqlite3
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager, suppress
from decimal import Decimal
from typing import Annotated

from fastapi import Depends, FastAPI, Header, Query, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from payments_api import __version__, cards
from payments_api.auth import READ_SCOPE, WRITE_SCOPE, Principal, require_scope
from payments_api.config import Settings
from payments_api.db import IdempotencyConflictError, NewTransaction, Repository
from payments_api.events import Publisher, publisher_from_settings, relay_outbox
from payments_api.models import Status, Transaction, TransactionCreate, TransactionList
from payments_api.observability import (
    BodySizeLimitMiddleware,
    Metrics,
    configure_logging,
    install_http_middleware,
)

logger = logging.getLogger("payments_api")

IDEMPOTENCY_KEY_PATTERN = r"^[A-Za-z0-9_-]{8,64}$"

# Placeholder risk rule: decline anything over a per-currency single-payment limit.
SINGLE_PAYMENT_LIMIT = {"JPY": Decimal(1_500_000), "INR": Decimal(800_000)}
DEFAULT_SINGLE_PAYMENT_LIMIT = Decimal(10_000)


def decide(body: TransactionCreate) -> Status:
    limit = SINGLE_PAYMENT_LIMIT.get(body.currency, DEFAULT_SINGLE_PAYMENT_LIMIT)
    return "declined" if body.amount > limit else "approved"


def _request_hash(body: TransactionCreate, card_fingerprint: str) -> str:
    canonical = json.dumps(
        {
            "card": card_fingerprint,
            "amount": str(body.amount),
            "currency": body.currency,
            "merchant_id": body.merchant_id,
            "description": body.description,
        },
        sort_keys=True,
    )
    return hashlib.sha256(canonical.encode()).hexdigest()


async def _relay_forever(repo: Repository, publisher: Publisher, interval: float) -> None:
    while True:
        try:
            await asyncio.to_thread(relay_outbox, repo, publisher)
        except Exception:
            logger.exception("outbox relay failed")
        await asyncio.sleep(interval)


def create_app(settings: Settings | None = None, publisher: Publisher | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    configure_logging(settings.log_level)
    repo = Repository(settings.database_path)
    metrics = Metrics()
    event_publisher = publisher or publisher_from_settings(settings)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        task = None
        if settings.outbox_relay_interval > 0:
            task = asyncio.create_task(
                _relay_forever(repo, event_publisher, settings.outbox_relay_interval)
            )
        logger.info("startup", extra={"version": __version__})
        yield
        if task is not None:
            task.cancel()
            with suppress(asyncio.CancelledError):
                await task
        close = getattr(event_publisher, "close", None)
        if callable(close):
            close()

    app = FastAPI(
        title="Payments API",
        version=__version__,
        lifespan=lifespan,
        docs_url="/docs" if settings.enable_docs else None,
        openapi_url="/openapi.json" if settings.enable_docs else None,
        redoc_url=None,
    )
    app.state.settings = settings
    app.state.repo = repo

    # Middleware added last runs first, so request IDs and security headers
    # also cover 413 responses.
    app.add_middleware(BodySizeLimitMiddleware, max_bytes=settings.max_body_bytes)
    install_http_middleware(app, metrics)

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        # FastAPI's default 422 echoes the rejected input back, which could
        # include a card number. Return only where and why validation failed.
        errors = [
            {"loc": list(err.get("loc", ())), "msg": err.get("msg", ""), "type": err.get("type")}
            for err in exc.errors()
        ]
        return JSONResponse(status_code=422, content={"detail": errors})

    @app.exception_handler(IdempotencyConflictError)
    async def idempotency_conflict(_: Request, __: IdempotencyConflictError) -> JSONResponse:
        return JSONResponse(
            status_code=409,
            content={"detail": "Idempotency-Key was already used with a different request"},
        )

    @app.exception_handler(Exception)
    async def unhandled(_: Request, exc: Exception) -> JSONResponse:
        logger.error("unhandled error", exc_info=exc)
        return JSONResponse(status_code=500, content={"detail": "internal server error"})

    @app.get("/healthz", include_in_schema=False)
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/readyz", include_in_schema=False)
    def readyz() -> JSONResponse:
        try:
            repo.ping()
        except sqlite3.Error:
            logger.exception("readiness check failed")
            return JSONResponse(status_code=503, content={"status": "unavailable"})
        return JSONResponse(content={"status": "ready"})

    @app.get("/metrics", include_in_schema=False)
    def metrics_endpoint() -> Response:
        return Response(generate_latest(metrics.registry), media_type=CONTENT_TYPE_LATEST)

    @app.post(
        "/v1/transactions",
        status_code=status.HTTP_201_CREATED,
        response_model=Transaction,
        responses={200: {"description": "Idempotent replay of an earlier request"}},
    )
    def create_transaction(
        body: TransactionCreate,
        response: Response,
        principal: Annotated[Principal, Depends(require_scope(WRITE_SCOPE))],
        idempotency_key: Annotated[str | None, Header(pattern=IDEMPOTENCY_KEY_PATTERN)] = None,
    ) -> Transaction:
        pan = body.card_number.get_secret_value()
        card_fingerprint = cards.fingerprint(pan, settings.pan_hmac_key)
        txn, created = repo.create(
            NewTransaction(
                owner=principal.subject,
                card_fingerprint=card_fingerprint,
                card_last4=cards.last4(pan),
                amount=body.amount,
                currency=body.currency,
                merchant_id=body.merchant_id,
                description=body.description,
                status=decide(body),
                idempotency_key=idempotency_key,
                request_hash=_request_hash(body, card_fingerprint),
            )
        )
        response.headers["Location"] = f"/v1/transactions/{txn.id}"
        if created:
            metrics.transactions.labels(txn.currency, txn.status).inc()
            logger.info(
                "transaction created",
                extra={
                    "transaction_id": txn.id,
                    "subject": principal.subject,
                    "card": cards.mask(pan),
                    "status": txn.status,
                },
            )
        else:
            response.status_code = status.HTTP_200_OK
            response.headers["Idempotent-Replayed"] = "true"
        return txn

    @app.get("/v1/transactions/{transaction_id}", response_model=Transaction)
    def get_transaction(
        transaction_id: uuid.UUID,
        principal: Annotated[Principal, Depends(require_scope(READ_SCOPE))],
    ) -> Transaction | JSONResponse:
        # Lookups are scoped to the caller, so another user's ID returns 404,
        # not 403. That avoids revealing which IDs exist.
        txn = repo.get(principal.subject, str(transaction_id))
        if txn is None:
            return JSONResponse(status_code=404, content={"detail": "transaction not found"})
        return txn

    @app.get("/v1/transactions", response_model=TransactionList)
    def list_transactions(
        principal: Annotated[Principal, Depends(require_scope(READ_SCOPE))],
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
    ) -> TransactionList:
        return TransactionList(items=repo.list_for(principal.subject, limit))

    return app
