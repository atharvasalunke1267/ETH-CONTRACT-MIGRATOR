"""Report-shape tests (T2.3, pure data)."""

from __future__ import annotations

import json
from typing import Any

from mguard.chain import V1Record, V2Record
from mguard.invariants import evaluate_invariants
from mguard.report import build_report, save_report

K0 = "0x" + "aa" * 32
K1 = "0x" + "bb" * 32
BAD = "0x3333333333333333333333333333333333333333"


def test_report_shape_matches_schema(tmp_path: Any) -> None:
    v1s = [
        V1Record(key=K0, label="alice", owner=BAD, expiry=10),
        V1Record(key=K1, label="bob", owner=BAD, expiry=20),
    ]
    v2s = [V2Record(key=K0, label="alice", owner=BAD, expiry=10, migrated_at=5)]
    invariants, rows = evaluate_invariants(v1s, v2s)
    report = build_report(
        network_id=31337,
        v1_address="0x" + "11" * 20,
        v2_address="0x" + "22" * 20,
        v1_records=v1s,
        v2_records=v2s,
        invariants=invariants,
        records=rows,
    )
    assert report["network"] == 31337
    assert report["countV1"] == 2
    assert report["countV2"] == 1
    assert [i["id"] for i in report["invariants"]] == ["I1", "I2", "I3", "I4"]
    statuses = {i["id"]: i["status"] for i in report["invariants"]}
    assert statuses["I3"] == "FAIL"
    missing_row = next(r for r in report["records"] if r["key"] == K1)
    assert missing_row["status"] == "MISSING"
    assert missing_row["v1"]["expiry"] == 20 and missing_row["v2"] is None


def test_report_is_valid_json(tmp_path: Any) -> None:
    v1s = [V1Record(key=K0, label="alice", owner=BAD, expiry=10)]
    v2s = [V2Record(key=K0, label="alice", owner=BAD, expiry=10, migrated_at=5)]
    invariants, rows = evaluate_invariants(v1s, v2s)
    report = build_report(
        network_id=31337,
        v1_address="0x" + "11" * 20,
        v2_address="0x" + "22" * 20,
        v1_records=v1s,
        v2_records=v2s,
        invariants=invariants,
        records=rows,
    )
    path = save_report(report, tmp_path / "report.json")
    parsed = json.loads(path.read_text(encoding="utf-8"))
    assert parsed == report
