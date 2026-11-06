"""Building and writing the JSON report (T2.3).

The shape follows ARCHITECTURE.md's pseudo-schema:

Report {
  generatedAt, network, v1Address, v2Address,
  countV1, countV2,
  invariants: [ { id, name, status, offenders: [key] } ],
  records: [ { key, label, v1: {owner, expiry}, v2: {owner, expiry} | null,
               status: OK|MISMATCH|MISSING|PHANTOM } ]
}
"""

from __future__ import annotations

import json
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from mguard.chain import V1Record, V2Record
from mguard.invariants import InvariantResult, RecordRow


def build_report(
    *,
    network_id: int,
    v1_address: str,
    v2_address: str,
    v1_records: list[V1Record],
    v2_records: list[V2Record],
    invariants: list[InvariantResult],
    records: list[RecordRow],
) -> dict[str, Any]:
    """Assemble the report dict exactly as the UI expects it."""
    return {
        "generatedAt": datetime.now(UTC).isoformat(timespec="seconds"),
        "network": network_id,
        "v1Address": v1_address,
        "v2Address": v2_address,
        "countV1": len(v1_records),
        "countV2": len(v2_records),
        "invariants": [
            {
                "id": result.id,
                "name": result.name,
                "status": result.status,
                "offenders": list(result.offenders),
            }
            for result in invariants
        ],
        "records": [
            {
                "key": row.key,
                "label": row.label,
                "v1": None
                if row.v1_owner is None
                else {"owner": row.v1_owner, "expiry": row.v1_expiry},
                "v2": None
                if row.v2_owner is None
                else {
                    "owner": row.v2_owner,
                    "expiry": row.v2_expiry,
                    "migratedAt": row.v2_migrated_at,
                },
                "status": row.status,
            }
            for row in records
        ],
    }


def save_report(report: dict[str, Any], path: Path) -> Path:
    """Write the report as pretty-printed JSON and return the path."""
    path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    return path
