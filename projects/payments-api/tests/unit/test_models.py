from decimal import Decimal
from typing import Any

import pytest
from pydantic import ValidationError

from payments_api.db import from_minor, to_minor
from payments_api.models import TransactionCreate

VALID: dict[str, Any] = {
    "card_number": "4111 1111 1111 1111",
    "amount": "10.00",
    "currency": "GBP",
    "merchant_id": "shop-1",
}


def test_valid_payment_is_normalised() -> None:
    body = TransactionCreate(**VALID)
    assert body.card_number.get_secret_value() == "4111111111111111"
    assert body.amount == Decimal("10.00")


def test_card_number_is_hidden_from_repr() -> None:
    assert "4111" not in repr(TransactionCreate(**VALID))


@pytest.mark.parametrize(
    "overrides",
    [
        {"card_number": "4111111111111112"},  # fails Luhn
        {"card_number": "411111111111"},  # too short
        {"amount": "0"},
        {"amount": "-5.00"},
        {"amount": "10.001"},  # sub-penny
        {"amount": "1000000.01"},  # over the maximum
        {"amount": "NaN"},
        {"currency": "XYZ"},
        {"currency": "gbp"},
        {"currency": "JPY", "amount": "100.50"},  # yen has no minor unit
        {"merchant_id": "x"},
        {"merchant_id": "shop'; DROP TABLE transactions;--"},
        {"description": "line\nbreak"},
        {"description": "x" * 141},
        {"unexpected": "field"},
    ],
)
def test_invalid_payments_are_rejected(overrides: dict[str, Any]) -> None:
    with pytest.raises(ValidationError):
        TransactionCreate(**{**VALID, **overrides})


@pytest.mark.parametrize(
    ("amount", "currency", "minor"),
    [("25.50", "GBP", 2550), ("0.01", "USD", 1), ("1500", "JPY", 1500)],
)
def test_minor_unit_conversion_round_trips(amount: str, currency: str, minor: int) -> None:
    assert to_minor(Decimal(amount), currency) == minor
    assert from_minor(minor, currency) == Decimal(amount)
