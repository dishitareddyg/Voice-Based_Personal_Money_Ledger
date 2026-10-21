"""Generate an Argon2id hash for seeding SQL or an administrator account.

Usage:
    python -m app.scripts.hash_password "MyStrongPassword"
    python -m app.scripts.hash_password            # prompts without echo
"""

from __future__ import annotations

import argparse
import getpass

from app.core.security import hash_password


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("password", nargs="?", help="Password to hash")
    args = parser.parse_args()

    password = args.password
    if not password:
        password = getpass.getpass("Password: ")
        confirmation = getpass.getpass("Confirm password: ")
        if password != confirmation:
            raise SystemExit("Passwords do not match.")
    if len(password) < 8:
        raise SystemExit("Password must be at least 8 characters.")

    print(hash_password(password))


if __name__ == "__main__":
    main()
