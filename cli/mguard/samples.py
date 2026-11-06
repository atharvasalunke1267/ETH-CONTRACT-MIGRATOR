"""Demo seed data shared by the Solidity Seed script and `mguard seed`.

Keep this list in sync with script/Seed.s.sol.
"""

from __future__ import annotations

from dataclasses import dataclass

DEMO_LABELS: tuple[str, ...] = (
    "alice",
    "bob",
    "carol",
    "dave",
    "erin",
    "frank",
    "grace",
    "heidi",
    "ivan",
    "judy",
)


@dataclass(frozen=True)
class SampleRecord:
    """One pre-defined record used by `mguard seed`."""

    label: str
    owner: str  # hex address
    expiry: int


def demo_records() -> list[SampleRecord]:
    """Return the ten demo records, mirroring script/Seed.s.sol."""
    return [
        SampleRecord(
            label=label,
            owner=f"0x{10001 + i:040x}",  # tidy, distinct demo owners
            expiry=1_800_000_000 + i,  # roughly year 2027
        )
        for i, label in enumerate(DEMO_LABELS)
    ]
