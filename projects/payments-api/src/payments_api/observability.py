"""Logging, metrics and HTTP hardening middleware."""

from __future__ import annotations

import contextvars
import json
import logging
import re
import time
import uuid
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

from fastapi import FastAPI, Request, Response
from prometheus_client import CollectorRegistry, Counter, Histogram
from starlette.types import ASGIApp, Message, Receive, Scope, Send

request_id_var: contextvars.ContextVar[str] = contextvars.ContextVar("request_id", default="-")

# Anything that looks like a card number is masked in log output, as a
# last line of defence if a PAN ever reaches a log call.
_PAN_PATTERN = re.compile(r"(?<!\d)\d{13,19}(?!\d)")
_REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9-]{8,64}$")
_STANDARD_ATTRS = set(vars(logging.makeLogRecord({}))) | {"message", "asctime", "taskName"}

SECURITY_HEADERS = {
    "Cache-Control": "no-store",
    "Content-Security-Policy": "default-src 'none'; frame-ancestors 'none'",
    "Referrer-Policy": "no-referrer",
    "Strict-Transport-Security": "max-age=63072000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
}
# Swagger UI needs scripts and styles, so /docs gets a looser policy when enabled.
_DOCS_PATHS = ("/docs", "/openapi.json")


def redact(text: str) -> str:
    return _PAN_PATTERN.sub("[REDACTED_PAN]", text)


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry: dict[str, Any] = {
            "ts": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
            "request_id": request_id_var.get(),
        }
        for key, value in vars(record).items():
            if key not in _STANDARD_ATTRS and not key.startswith("_"):
                entry[key] = value
        if record.exc_info:
            entry["exc"] = self.formatException(record.exc_info)
        return redact(json.dumps(entry, default=str))


def configure_logging(level: str) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(level)
    # Uvicorn's own access log is replaced by ours, which has the request ID.
    logging.getLogger("uvicorn.access").disabled = True


class Metrics:
    def __init__(self) -> None:
        self.registry = CollectorRegistry()
        self.requests = Counter(
            "http_requests_total",
            "HTTP requests",
            ["method", "route", "status"],
            registry=self.registry,
        )
        self.latency = Histogram(
            "http_request_duration_seconds",
            "HTTP request latency",
            ["method", "route"],
            registry=self.registry,
        )
        self.transactions = Counter(
            "transactions_created_total",
            "Transactions created",
            ["currency", "status"],
            registry=self.registry,
        )


def _route_template(request: Request) -> str:
    # Label metrics by route template, not raw path, to keep cardinality bounded.
    route = request.scope.get("route")
    path = getattr(route, "path", None)
    return path if isinstance(path, str) else "unmatched"


def install_http_middleware(app: FastAPI, metrics: Metrics) -> None:
    access_log = logging.getLogger("payments_api.access")

    @app.middleware("http")
    async def observe(
        request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        incoming = request.headers.get("x-request-id", "")
        request_id = incoming if _REQUEST_ID_PATTERN.match(incoming) else str(uuid.uuid4())
        token = request_id_var.set(request_id)
        start = time.perf_counter()
        status = 500
        try:
            response = await call_next(request)
            status = response.status_code
        finally:
            elapsed = time.perf_counter() - start
            route = _route_template(request)
            metrics.requests.labels(request.method, route, str(status)).inc()
            metrics.latency.labels(request.method, route).observe(elapsed)
            access_log.info(
                "request",
                extra={
                    "method": request.method,
                    "route": route,
                    "status": status,
                    "duration_ms": round(elapsed * 1000, 2),
                },
            )
            request_id_var.reset(token)
        response.headers["X-Request-ID"] = request_id
        for name, value in SECURITY_HEADERS.items():
            response.headers.setdefault(name, value)
        if request.url.path.startswith(_DOCS_PATHS):
            del response.headers["Content-Security-Policy"]
        return response


class BodySizeLimitMiddleware:
    """Reject request bodies over ``max_bytes`` with 413 before they are parsed."""

    def __init__(self, app: ASGIApp, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        length = dict(scope["headers"]).get(b"content-length")
        if length is not None and (not length.isdigit() or int(length) > self.max_bytes):
            await self._reject(send)
            return

        # Bodies sent without Content-Length are counted as they stream in. Once
        # over the limit we answer 413 ourselves, tell the app the client went
        # away, and drop anything the app tries to send afterwards.
        received = 0
        rejected = False
        disconnect: Message = {"type": "http.disconnect"}

        async def limited_receive() -> Message:
            nonlocal received, rejected
            if rejected:
                return disconnect
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    rejected = True
                    await self._reject(send)
                    return disconnect
            return message

        async def guarded_send(message: Message) -> None:
            if not rejected:
                await send(message)

        await self.app(scope, limited_receive, guarded_send)

    @staticmethod
    async def _reject(send: Send) -> None:
        body = b'{"detail":"request body too large"}'
        await send(
            {
                "type": "http.response.start",
                "status": 413,
                "headers": [
                    (b"content-type", b"application/json"),
                    (b"content-length", str(len(body)).encode()),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})
