import json
import logging
import sys

from payments_api.observability import JsonFormatter, redact, request_id_var


def test_redact_masks_card_like_numbers_only() -> None:
    assert redact("card 4111111111111111 used") == "card [REDACTED_PAN] used"
    assert redact("order 12345 total 9999") == "order 12345 total 9999"


def _record(msg: str, **extra: object) -> logging.LogRecord:
    record = logging.LogRecord("test", logging.INFO, __file__, 1, msg, None, None)
    record.__dict__.update(extra)
    return record


def test_json_formatter_emits_structured_redacted_logs() -> None:
    token = request_id_var.set("req-12345678")
    try:
        line = JsonFormatter().format(_record("paid with 4111111111111111", amount="5.00"))
    finally:
        request_id_var.reset(token)

    entry = json.loads(line)
    assert entry["msg"] == "paid with [REDACTED_PAN]"
    assert entry["amount"] == "5.00"
    assert entry["request_id"] == "req-12345678"
    assert entry["level"] == "INFO"
    assert "4111111111111111" not in line


def test_json_formatter_includes_redacted_exceptions() -> None:
    try:
        raise ValueError("bad card 4111111111111111")
    except ValueError:
        record = _record("failed")
        record.exc_info = sys.exc_info()
    line = JsonFormatter().format(record)
    assert "ValueError" in json.loads(line)["exc"]
    assert "4111111111111111" not in line
