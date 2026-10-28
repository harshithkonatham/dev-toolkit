import pytest

from payments_api import cards


@pytest.mark.parametrize(
    "pan",
    ["4111111111111111", "5555555555554444", "378282246310005", "6011111111111117"],
)
def test_luhn_accepts_valid_numbers(pan: str) -> None:
    assert cards.luhn_valid(pan)


@pytest.mark.parametrize("pan", ["4111111111111112", "", "4111-1111-1111-1111", "abcd"])
def test_luhn_rejects_invalid_numbers(pan: str) -> None:
    assert not cards.luhn_valid(pan)


def test_mask_and_last4_reveal_only_last_four_digits() -> None:
    assert cards.mask("4111111111111111") == "************1111"
    assert cards.last4("4111111111111111") == "1111"


def test_fingerprint_is_stable_keyed_and_does_not_contain_the_pan() -> None:
    pan = "4111111111111111"
    first = cards.fingerprint(pan, b"key-one")
    assert first == cards.fingerprint(pan, b"key-one")
    assert first != cards.fingerprint(pan, b"key-two")
    assert pan not in first
    assert len(first) == 64
