import json
from typing import Any, ClassVar

import pytest

from payments_api import events
from payments_api.config import Settings


class FakeChannel:
    def __init__(self, fail: bool = False) -> None:
        self.fail = fail
        self.is_closed = False
        self.published: list[dict[str, Any]] = []
        self.confirms = False

    def exchange_declare(self, name: str, exchange_type: str, durable: bool) -> None:
        assert durable

    def confirm_delivery(self) -> None:
        self.confirms = True

    def basic_publish(self, **kwargs: Any) -> None:
        if self.fail:
            raise ConnectionError("broker went away")
        self.published.append(kwargs)


class FakeConnection:
    instances: ClassVar[list["FakeConnection"]] = []
    fail_next: ClassVar[bool] = False

    def __init__(self, params: Any) -> None:
        self.params = params
        self.is_open = True
        self._channel = FakeChannel(fail=FakeConnection.fail_next)
        FakeConnection.fail_next = False
        FakeConnection.instances.append(self)

    def channel(self) -> FakeChannel:
        return self._channel

    def close(self) -> None:
        self.is_open = False


@pytest.fixture(autouse=True)
def fake_pika(monkeypatch: pytest.MonkeyPatch) -> None:
    FakeConnection.instances = []
    monkeypatch.setattr(events.pika, "BlockingConnection", FakeConnection)


def test_publishes_persistent_confirmed_message() -> None:
    publisher = events.RabbitMQPublisher("amqp://guest:guest@localhost:5672/%2F")
    publisher.publish(5, "transaction.created", {"transaction_id": "t-1"})

    [conn] = FakeConnection.instances
    assert conn._channel.confirms
    [msg] = conn._channel.published
    assert msg["exchange"] == events.EXCHANGE
    assert msg["routing_key"] == "transaction.created"
    assert msg["mandatory"] is True
    assert json.loads(msg["body"]) == {"transaction_id": "t-1"}
    assert msg["properties"].message_id == "5"
    assert msg["properties"].delivery_mode == 2


def test_reuses_one_connection_for_many_events() -> None:
    publisher = events.RabbitMQPublisher("amqp://guest:guest@localhost:5672/%2F")
    for i in range(3):
        publisher.publish(i, "transaction.created", {})
    assert len(FakeConnection.instances) == 1


def test_failure_drops_connection_and_next_publish_reconnects() -> None:
    publisher = events.RabbitMQPublisher("amqp://guest:guest@localhost:5672/%2F")
    FakeConnection.fail_next = True
    with pytest.raises(ConnectionError):
        publisher.publish(1, "transaction.created", {})
    assert FakeConnection.instances[0].is_open is False

    publisher.publish(1, "transaction.created", {})
    assert len(FakeConnection.instances) == 2
    assert len(FakeConnection.instances[1]._channel.published) == 1


def test_close_is_safe_to_call_twice() -> None:
    publisher = events.RabbitMQPublisher("amqp://guest:guest@localhost:5672/%2F")
    publisher.publish(1, "transaction.created", {})
    publisher.close()
    publisher.close()
    assert FakeConnection.instances[0].is_open is False


def test_close_ignores_errors_from_a_broken_connection() -> None:
    publisher = events.RabbitMQPublisher("amqp://guest:guest@localhost:5672/%2F")
    publisher.publish(1, "transaction.created", {})

    def broken_close() -> None:
        raise ConnectionError("socket closed")

    FakeConnection.instances[0].close = broken_close  # type: ignore[method-assign]
    publisher.close()  # must not raise


def test_publisher_from_settings() -> None:
    base = {"jwt_secret": "s" * 40, "pan_hmac_key": b"k" * 40}
    assert isinstance(events.publisher_from_settings(Settings(**base)), events.LogPublisher)
    rabbit = Settings(**base, event_broker="rabbitmq", rabbitmq_url="amqps://u:p@h:5671/%2F")
    assert isinstance(events.publisher_from_settings(rabbit), events.RabbitMQPublisher)
