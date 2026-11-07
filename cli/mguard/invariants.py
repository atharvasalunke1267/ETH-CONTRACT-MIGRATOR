"""Invariant evaluation on plain Python data — no chain required (T2.2).

The four data invariants the CLI checks (the on-chain access rules I5/I6 are
proven by Foundry tests instead):

- I1 Ownership preserved: same owner in v2 for every v1 record.
- I2 Expiry preserved: same expiry, so expired stays expired.
- I3 No record lost: every v1 key exists in v2.
- I4 No phantom records: v2 holds no key absent from v1.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass, field

from mguard.chain import V1Record, V2Record

INVARIANT_NAMES: dict[str, str] = {
    "I1": "Ownership preserved",
    "I2": "Expiry preserved",
    "I3": "No record lost",
    "I4": "No phantom records",
}


@dataclass
class InvariantResult:
    """Outcome of one invariant over the two record lists."""

    id: str
    name: str
    status: str
    offenders: list[str] = field(default_factory=list)


@dataclass
class RecordRow:
    """One side-by-side row for the report's records table."""

    key: str
    label: str
    v1_owner: str | None
    v1_expiry: int | None
    v2_owner: str | None
    v2_expiry: int | None
    v2_migrated_at: int | None
    status: str


def evaluate_invariants(
    v1_records: Iterable[V1Record],
    v2_records: Iterable[V2Record],
) -> tuple[list[InvariantResult], list[RecordRow]]:
    """Compare both registries and return invariant results plus record rows.

    Rows carry `status` values OK, MISMATCH (an I1 or I2 violation),
    MISSING (I3) and PHANTOM (I4), so the UI can highlight records too.
    """
    v1_list = list(v1_records)
    v2_list = list(v2_records)
    v2_by_key: dict[str, V2Record] = {r.key: r for r in v2_list}
    v1_by_key: dict[str, V1Record] = {r.key: r for r in v1_list}

    owner_offenders: list[str] = []
    expiry_offenders: list[str] = []
    lost_keys: list[str] = []
    phantom_keys: list[str] = []
    rows: list[RecordRow] = []

    for v1 in v1_list:
        v2 = v2_by_key.get(v1.key)
        if v2 is None:
            lost_keys.append(v1.key)
            rows.append(_row(v1=v1, v2=None, status="MISSING"))
            continue

        status = "OK"
        if v2.owner != v1.owner:
            owner_offenders.append(v1.key)
            status = "MISMATCH"
        if v2.expiry != v1.expiry:
            expiry_offenders.append(v1.key)
            status = "MISMATCH"
        rows.append(_row(v1=v1, v2=v2, status=status))

    for v2 in v2_list:
        if v2.key not in v1_by_key:
            phantom_keys.append(v2.key)
            rows.append(_row(v1=None, v2=v2, status="PHANTOM"))

    results = [
        _result("I1", owner_offenders),
        _result("I2", expiry_offenders),
        _result("I3", lost_keys),
        _result("I4", phantom_keys),
    ]
    return results, rows


def _result(invariant_id: str, offenders: list[str]) -> InvariantResult:
    return InvariantResult(
        id=invariant_id,
        name=INVARIANT_NAMES[invariant_id],
        status="PASS" if not offenders else "FAIL",
        offenders=list(offenders),
    )


def _row(*, v1: V1Record | None, v2: V2Record | None, status: str) -> RecordRow:
    side = v1 if v1 is not None else v2
    assert side is not None
    return RecordRow(
        key=side.key,
        label=side.label,
        v1_owner=v1.owner if v1 else None,
        v1_expiry=v1.expiry if v1 else None,
        v2_owner=v2.owner if v2 else None,
        v2_expiry=v2.expiry if v2 else None,
        v2_migrated_at=v2.migrated_at if v2 else None,
        status=status,
    )
