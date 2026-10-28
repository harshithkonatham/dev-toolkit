"""Card number handling.

The full card number (PAN) is never stored or logged. We keep only the last four
digits for display and a keyed HMAC fingerprint, so the same card can be
recognised without being recoverable (in the spirit of PCI DSS requirement 3).
"""

from __future__ import annotations

import hashlib
import hmac


def luhn_valid(pan: str) -> bool:
    """Return True if ``pan`` is all digits and passes the Luhn checksum."""
    if not pan.isdigit():
        return False
    total = 0
    for index, char in enumerate(reversed(pan)):
        digit = int(char)
        if index % 2 == 1:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return total % 10 == 0


def last4(pan: str) -> str:
    return pan[-4:]


def mask(pan: str) -> str:
    """Show only the last four digits, e.g. ``************1111``."""
    return "*" * (len(pan) - 4) + pan[-4:]


def fingerprint(pan: str, key: bytes) -> str:
    """Keyed, one-way fingerprint of a card number."""
    return hmac.new(key, pan.encode("ascii"), hashlib.sha256).hexdigest()
