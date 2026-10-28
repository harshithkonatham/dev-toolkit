from pathlib import Path

import pytest

from payments_api.config import ConfigError, Settings

GOOD_SECRET = "s" * 40


@pytest.fixture(autouse=True)
def _clean_env(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in (
        "JWT_SECRET",
        "JWT_SECRET_FILE",
        "PAN_HMAC_KEY",
        "PAN_HMAC_KEY_FILE",
        "EVENT_BROKER",
        "RABBITMQ_URL",
        "RABBITMQ_URL_FILE",
        "RABBITMQ_ALLOW_PLAINTEXT",
    ):
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


@pytest.fixture
def _secrets(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JWT_SECRET", GOOD_SECRET)
    monkeypatch.setenv("PAN_HMAC_KEY", GOOD_SECRET)


@pytest.mark.usefixtures("_secrets")
def test_log_broker_is_the_default() -> None:
    settings = Settings.from_env()
    assert settings.event_broker == "log"
    assert settings.rabbitmq_url is None


@pytest.mark.usefixtures("_secrets")
def test_unknown_broker_is_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EVENT_BROKER", "carrier-pigeon")
    with pytest.raises(ConfigError, match="EVENT_BROKER"):
        Settings.from_env()


@pytest.mark.usefixtures("_secrets")
def test_rabbitmq_needs_a_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EVENT_BROKER", "rabbitmq")
    with pytest.raises(ConfigError, match="RABBITMQ_URL must be set"):
        Settings.from_env()


@pytest.mark.usefixtures("_secrets")
def test_rabbitmq_requires_tls_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EVENT_BROKER", "rabbitmq")
    monkeypatch.setenv("RABBITMQ_URL", "amqp://user:pass@broker:5672/%2F")
    with pytest.raises(ConfigError, match="amqps"):
        Settings.from_env()


@pytest.mark.usefixtures("_secrets")
def test_plaintext_allowed_only_when_opted_in(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EVENT_BROKER", "rabbitmq")
    monkeypatch.setenv("RABBITMQ_URL", "amqp://user:pass@localhost:5672/%2F")
    monkeypatch.setenv("RABBITMQ_ALLOW_PLAINTEXT", "true")
    assert Settings.from_env().rabbitmq_url == "amqp://user:pass@localhost:5672/%2F"


@pytest.mark.usefixtures("_secrets")
def test_broker_url_from_file_is_never_in_repr(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    url_file = tmp_path / "rabbitmq-url"
    url_file.write_text("amqps://svc:s3cret-password@broker:5671/payments\n")
    monkeypatch.setenv("EVENT_BROKER", "rabbitmq")
    monkeypatch.setenv("RABBITMQ_URL_FILE", str(url_file))

    settings = Settings.from_env()

    assert settings.rabbitmq_url == "amqps://svc:s3cret-password@broker:5671/payments"
    assert "s3cret" not in repr(settings)


@pytest.mark.usefixtures("_secrets")
def test_unreadable_broker_url_file(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("EVENT_BROKER", "rabbitmq")
    monkeypatch.setenv("RABBITMQ_URL_FILE", "/nonexistent/url")
    with pytest.raises(ConfigError, match="RABBITMQ_URL_FILE"):
        Settings.from_env()
