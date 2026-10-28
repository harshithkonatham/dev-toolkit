from pathlib import Path

import pytest

from payments_api.config import ConfigError, Settings

GOOD_SECRET = "s" * 40


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in ("JWT_SECRET", "JWT_SECRET_FILE", "PAN_HMAC_KEY", "PAN_HMAC_KEY_FILE"):
        monkeypatch.delenv(name, raising=False)


def test_refuses_to_start_without_secrets() -> None:
    with pytest.raises(ConfigError, match="JWT_SECRET"):
        Settings.from_env()


def test_rejects_short_secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JWT_SECRET", "too-short")
    monkeypatch.setenv("PAN_HMAC_KEY", GOOD_SECRET)
    with pytest.raises(ConfigError, match="at least 32"):
        Settings.from_env()


def test_reads_secrets_from_mounted_files(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    jwt_file = tmp_path / "jwt"
    jwt_file.write_text(GOOD_SECRET + "\n")
    monkeypatch.setenv("JWT_SECRET_FILE", str(jwt_file))
    monkeypatch.setenv("PAN_HMAC_KEY", "k" * 40)
    monkeypatch.setenv("ENABLE_DOCS", "true")
    monkeypatch.setenv("OUTBOX_RELAY_INTERVAL", "0.5")

    settings = Settings.from_env()

    assert settings.jwt_secret == GOOD_SECRET
    assert settings.pan_hmac_key == b"k" * 40
    assert settings.enable_docs is True
    assert settings.outbox_relay_interval == 0.5


def test_missing_secret_file_is_a_config_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JWT_SECRET_FILE", "/nonexistent/secret")
    with pytest.raises(ConfigError, match="could not be read"):
        Settings.from_env()


def test_invalid_number_is_a_config_error(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JWT_SECRET", GOOD_SECRET)
    monkeypatch.setenv("PAN_HMAC_KEY", GOOD_SECRET)
    monkeypatch.setenv("OUTBOX_RELAY_INTERVAL", "soon")
    with pytest.raises(ConfigError, match="OUTBOX_RELAY_INTERVAL"):
        Settings.from_env()


def test_repr_never_shows_secrets() -> None:
    settings = Settings(jwt_secret=GOOD_SECRET, pan_hmac_key=b"k" * 40)
    assert GOOD_SECRET not in repr(settings)
    assert "redacted" in repr(settings)
