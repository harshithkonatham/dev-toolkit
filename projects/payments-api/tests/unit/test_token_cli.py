import pytest

from payments_api.auth import READ_SCOPE, WRITE_SCOPE, decode_token
from payments_api.config import Settings
from payments_api.token_cli import main

SECRET = "cli-test-secret-that-is-long-enough-12345"


def test_cli_prints_a_valid_token(
    monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("JWT_SECRET", SECRET)
    main(["--subject", "alice", "--scope", READ_SCOPE, "--scope", WRITE_SCOPE])

    token = capsys.readouterr().out.strip()
    principal = decode_token(token, Settings(jwt_secret=SECRET, pan_hmac_key=b""))
    assert principal.subject == "alice"
    assert principal.scopes == {READ_SCOPE, WRITE_SCOPE}


def test_cli_rejects_unknown_scopes(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JWT_SECRET", SECRET)
    with pytest.raises(SystemExit):
        main(["--subject", "alice", "--scope", "admin"])
