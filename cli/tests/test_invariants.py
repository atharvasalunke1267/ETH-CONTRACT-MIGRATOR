"""Pure-data invariant tests, no chain required (T2.2)."""

from __future__ import annotations

from mguard.chain import V1Record, V2Record
from mguard.invariants import evaluate_invariants

K0 = "0x" + "aa" * 32
K1 = "0x" + "bb" * 32
K2 = "0x" + "cc" * 32
A0 = "0x1111111111111111111111111111111111111111"
A1 = "0x2222222222222222222222222222222222222222"


def v1(key: str, owner: str = A0, expiry: int = 100) -> V1Record:
    return V1Record(key=key, label=f"lbl-{key[:6]}", owner=owner, expiry=expiry)


def v2(key: str, owner: str = A0, expiry: int = 100) -> V2Record:
    return V2Record(
        key=key, label=f"lbl-{key[:6]}", owner=owner, expiry=expiry, migrated_at=5
    )


def result(invariants, invariant_id: str):
    return next(item for item in invariants if item.id == invariant_id)


def test_all_pass_when_migration_was_exact() -> None:
    v1s = [v1(K0), v1(K1, owner=A1, expiry=200)]
    v2s = [v2(K0), v2(K1, owner=A1, expiry=200)]
    results, rows = evaluate_invariants(v1s, v2s)
    assert all(item.status == "PASS" for item in results)
    assert [row.status for row in rows] == ["OK", "OK"]


def test_i1_catches_swapped_owner() -> None:
    v1s = [v1(K0), v1(K1)]
    v2s = [v2(K0), v2(K1, owner=A1)]  # K1 got a different owner
    results, rows = evaluate_invariants(v1s, v2s)
    first = result(results, "I1")
    assert first.status == "FAIL"
    assert first.offenders == [K1]
    assert rows[1].status == "MISMATCH"


def test_i2_catches_reset_expiry() -> None:
    v1s = [v1(K0), v1(K1)]
    v2s = [v2(K0), v2(K1, expiry=0)]
    results, rows = evaluate_invariants(v1s, v2s)
    second = result(results, "I2")
    assert second.status == "FAIL"
    assert second.offenders == [K1]
    assert rows[1].status == "MISMATCH"


def test_i3_catches_dropped_record() -> None:
    v1s = [v1(K0), v1(K1), v1(K2)]
    v2s = [v2(K0), v2(K1)]  # K2 never migrated ("drop the last one")
    results, rows = evaluate_invariants(v1s, v2s)
    third = result(results, "I3")
    assert third.status == "FAIL"
    assert third.offenders == [K2]
    assert rows[2].status == "MISSING"
    assert result(results, "I1").status == "PASS"  # others still hold


def test_i4_catches_phantom_record() -> None:
    v1s = [v1(K0)]
    v2s = [v2(K0), v2(K1)]  # K1 never existed in v1
    results, rows = evaluate_invariants(v1s, v2s)
    fourth = result(results, "I4")
    assert fourth.status == "FAIL"
    assert fourth.offenders == [K1]
    assert rows[1].status == "PHANTOM"
    assert result(results, "I3").status == "PASS"  # others still hold


def test_empty_v1_means_no_phantoms() -> None:
    results, rows = evaluate_invariants([], [])
    assert all(item.status == "PASS" for item in results)
    assert rows == []


def test_offender_keys_are_named_as_hex_strings() -> None:
    v1s = [v1(K0)]
    v2s = [v2(K0, owner=A1)]
    results, _ = evaluate_invariants(v1s, v2s)
    first = results[0]
    assert first.offenders[0].startswith("0x")
