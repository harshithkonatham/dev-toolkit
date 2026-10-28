import time
from dataclasses import replace
from typing import Any

import jwt
import pytest

from payments_api.auth import READ_SCOPE, InvalidTokenError, decode_token, issue_token
from payments_api.config import Settings


def _claims(settings: Settings, **overrides: Any) -> dict[str, Any]:
    now = int(time.time())
    claims: dict[str, Any] = {
        "sub": "alice",
        "scope": READ_SCOPE,
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": now,
        "exp": now + 60,
    }
    claims.update(overrides)
    return claims


def test_issued_token_round_trips(settings: Settings) -> None:
    principal = decode_token(issue_token(settings, "alice", [READ_SCOPE]), settings)
    assert principal.subject == "alice"
    assert principal.scopes == {READ_SCOPE}


def test_expired_token_is_rejected(settings: Settings) -> None:
    token = issue_token(settings, "alice", [READ_SCOPE], ttl_seconds=-120)
    with pytest.raises(InvalidTokenError):
        decode_token(token, settings)


def test_token_signed_with_another_key_is_rejected(settings: Settings) -> None:
    other = replace(settings, jwt_secret="a-completely-different-secret-value-1234")
    with pytest.raises(InvalidTokenError):
        decode_token(issue_token(other, "alice", [READ_SCOPE]), settings)


@pytest.mark.parametrize(
    "overrides", [{"aud": "someone-else"}, {"iss": "evil-issuer"}, {"sub": ""}, {"sub": 42}]
)
def test_wrong_claims_are_rejected(settings: Settings, overrides: dict[str, Any]) -> None:
    token = jwt.encode(_claims(settings, **overrides), settings.jwt_secret, algorithm="HS256")
    with pytest.raises(InvalidTokenError):
        decode_token(token, settings)


@pytest.mark.parametrize("missing", ["exp", "iat", "sub", "iss", "aud"])
def test_required_claims_must_be_present(settings: Settings, missing: str) -> None:
    claims = _claims(settings)
    del claims[missing]
    token = jwt.encode(claims, settings.jwt_secret, algorithm="HS256")
    with pytest.raises(InvalidTokenError):
        decode_token(token, settings)


def test_unsigned_alg_none_token_is_rejected(settings: Settings) -> None:
    token = jwt.encode(_claims(settings), key=None, algorithm="none")
    with pytest.raises(InvalidTokenError):
        decode_token(token, settings)


def test_other_algorithms_are_rejected(settings: Settings) -> None:
    token = jwt.encode(_claims(settings), settings.jwt_secret, algorithm="HS512")
    with pytest.raises(InvalidTokenError):
        decode_token(token, settings)


def test_non_string_scope_grants_nothing(settings: Settings) -> None:
    token = jwt.encode(
        _claims(settings, scope=["transactions:write"]), settings.jwt_secret, algorithm="HS256"
    )
    assert decode_token(token, settings).scopes == frozenset()
