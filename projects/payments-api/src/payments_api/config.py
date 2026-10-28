"""Runtime settings, read from the environment.

Secrets have no defaults. Each one can be passed directly (``JWT_SECRET``) or as a
path to a mounted file (``JWT_SECRET_FILE``), which is how Kubernetes and Docker
secrets are usually provided. The service refuses to start without them.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

MIN_SECRET_LENGTH = 32


class ConfigError(RuntimeError):
    """Raised when required configuration is missing or invalid."""


def _read_secret(name: str) -> str:
    file_path = os.environ.get(f"{name}_FILE")
    if file_path:
        try:
            value = Path(file_path).read_text(encoding="utf-8").strip()
        except OSError as exc:
            raise ConfigError(f"{name}_FILE could not be read") from exc
    else:
        value = os.environ.get(name, "")
    if len(value) < MIN_SECRET_LENGTH:
        raise ConfigError(f"{name} must be set and at least {MIN_SECRET_LENGTH} characters")
    return value


def _read_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return default
    try:
        return float(raw)
    except ValueError as exc:
        raise ConfigError(f"{name} must be a number") from exc


@dataclass(frozen=True, repr=False)
class Settings:
    jwt_secret: str
    pan_hmac_key: bytes
    jwt_issuer: str = "payments-api"
    jwt_audience: str = "payments-api"
    database_path: str = "payments.db"
    log_level: str = "INFO"
    enable_docs: bool = False
    outbox_relay_interval: float = 2.0
    max_body_bytes: int = 16 * 1024

    def __repr__(self) -> str:  # never print secrets
        return (
            f"Settings(issuer={self.jwt_issuer!r}, audience={self.jwt_audience!r}, "
            f"database_path={self.database_path!r}, secrets=<redacted>)"
        )

    @classmethod
    def from_env(cls) -> Settings:
        return cls(
            jwt_secret=_read_secret("JWT_SECRET"),
            pan_hmac_key=_read_secret("PAN_HMAC_KEY").encode("utf-8"),
            jwt_issuer=os.environ.get("JWT_ISSUER", "payments-api"),
            jwt_audience=os.environ.get("JWT_AUDIENCE", "payments-api"),
            database_path=os.environ.get("DATABASE_PATH", "payments.db"),
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            enable_docs=os.environ.get("ENABLE_DOCS", "false").lower() == "true",
            outbox_relay_interval=_read_float("OUTBOX_RELAY_INTERVAL", 2.0),
        )
