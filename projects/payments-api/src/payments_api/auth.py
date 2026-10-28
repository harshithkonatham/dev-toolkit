"""Bearer-token authentication and scope-based authorization.

Tokens are HS256 JWTs. The algorithm is pinned (no ``alg: none`` or algorithm
confusion), and ``exp``, ``iat``, ``sub``, ``iss`` and ``aud`` are all required.
"""

from __future__ import annotations

import time
from collections.abc import Callable, Iterable
from dataclasses import dataclass
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from payments_api.config import Settings

ALGORITHM = "HS256"
READ_SCOPE = "transactions:read"
WRITE_SCOPE = "transactions:write"

_bearer = HTTPBearer(auto_error=False)


@dataclass(frozen=True)
class Principal:
    subject: str
    scopes: frozenset[str]


class InvalidTokenError(Exception):
    pass


def issue_token(
    settings: Settings, subject: str, scopes: Iterable[str], ttl_seconds: int = 900
) -> str:
    now = int(time.time())
    claims = {
        "sub": subject,
        "scope": " ".join(sorted(set(scopes))),
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": now,
        "exp": now + ttl_seconds,
    }
    return jwt.encode(claims, settings.jwt_secret, algorithm=ALGORITHM)


def decode_token(token: str, settings: Settings) -> Principal:
    try:
        claims = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[ALGORITHM],
            audience=settings.jwt_audience,
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "iat", "sub", "iss", "aud"]},
            leeway=30,
        )
    except jwt.PyJWTError as exc:
        raise InvalidTokenError(str(exc)) from exc
    subject = claims["sub"]
    if not isinstance(subject, str) or not subject:
        raise InvalidTokenError("sub must be a non-empty string")
    scope = claims.get("scope", "")
    scopes = frozenset(scope.split()) if isinstance(scope, str) else frozenset()
    return Principal(subject=subject, scopes=scopes)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def current_principal(
    request: Request,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> Principal:
    if credentials is None:
        raise _unauthorized("missing bearer token")
    settings: Settings = request.app.state.settings
    try:
        return decode_token(credentials.credentials, settings)
    except InvalidTokenError:
        # Don't tell the caller why the token failed.
        raise _unauthorized("invalid or expired token") from None


def require_scope(scope: str) -> Callable[[Principal], Principal]:
    def dependency(principal: Annotated[Principal, Depends(current_principal)]) -> Principal:
        if scope not in principal.scopes:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="insufficient scope")
        return principal

    return dependency
