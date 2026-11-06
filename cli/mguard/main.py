"""CLI entry point for mguard.

Run as: python -m mguard.main --help  (from inside the cli/ folder).
"""

from __future__ import annotations

import click


@click.group(help="MigrateGuard: verify a v1 -> v2 registry migration.")
def main() -> None:
    """mguard — check that a contract migration preserved every invariant."""


if __name__ == "__main__":
    main()
