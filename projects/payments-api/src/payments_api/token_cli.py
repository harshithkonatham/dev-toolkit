"""Mint a short-lived access token for local testing.

    JWT_SECRET=... python -m payments_api.token_cli --subject alice \\
        --scope transactions:read --scope transactions:write
"""

from __future__ import annotations

import argparse
import os

from payments_api.auth import READ_SCOPE, WRITE_SCOPE, issue_token
from payments_api.config import Settings, _read_secret


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--subject", required=True)
    parser.add_argument(
        "--scope",
        action="append",
        choices=[READ_SCOPE, WRITE_SCOPE],
        default=[],
        help="repeat for several scopes",
    )
    parser.add_argument("--ttl", type=int, default=900, help="lifetime in seconds")
    args = parser.parse_args(argv)
    settings = Settings(
        jwt_secret=_read_secret("JWT_SECRET"),
        pan_hmac_key=b"",  # not needed to sign tokens
        jwt_issuer=os.environ.get("JWT_ISSUER", "payments-api"),
        jwt_audience=os.environ.get("JWT_AUDIENCE", "payments-api"),
    )
    print(issue_token(settings, args.subject, args.scope, args.ttl))


if __name__ == "__main__":
    main()
