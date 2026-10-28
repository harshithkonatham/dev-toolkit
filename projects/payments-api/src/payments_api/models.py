"""Request and response schemas. Validation happens here, at the edge."""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator, model_validator

from payments_api.cards import luhn_valid

Currency = Literal["GBP", "EUR", "USD", "JPY", "CAD", "AUD", "CHF", "SGD", "INR"]
ZERO_DECIMAL_CURRENCIES = frozenset({"JPY"})
Status = Literal["approved", "declined"]

MAX_AMOUNT = Decimal("1000000.00")
MERCHANT_ID_PATTERN = r"^[A-Za-z0-9_-]{3,64}$"


class TransactionCreate(BaseModel):
    """A new card transaction. Unknown fields are rejected."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    # SecretStr keeps the card number out of repr(), logs and tracebacks.
    card_number: SecretStr
    amount: Annotated[Decimal, Field(gt=0, le=MAX_AMOUNT, max_digits=9, decimal_places=2)]
    currency: Currency
    merchant_id: Annotated[str, Field(pattern=MERCHANT_ID_PATTERN)]
    description: Annotated[str | None, Field(max_length=140)] = None

    @field_validator("card_number")
    @classmethod
    def _valid_card(cls, value: SecretStr) -> SecretStr:
        pan = value.get_secret_value().replace(" ", "")
        if not 13 <= len(pan) <= 19 or not luhn_valid(pan):
            raise ValueError("card_number is not a valid card number")
        return SecretStr(pan)

    @field_validator("description")
    @classmethod
    def _printable(cls, value: str | None) -> str | None:
        if value is not None and not value.isprintable():
            raise ValueError("description must not contain control characters")
        return value

    @model_validator(mode="after")
    def _currency_precision(self) -> TransactionCreate:
        if self.currency in ZERO_DECIMAL_CURRENCIES and self.amount != self.amount.to_integral():
            raise ValueError(f"{self.currency} amounts cannot have decimals")
        return self


class Transaction(BaseModel):
    id: str
    card_last4: str
    amount: Decimal
    currency: Currency
    merchant_id: str
    description: str | None
    status: Status
    created_at: datetime


class TransactionList(BaseModel):
    items: list[Transaction]
