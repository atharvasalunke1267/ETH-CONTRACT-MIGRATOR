"""End-to-end tests against a running Anvil chain (T2.5).

These tests deploy fresh contracts from forge's out/ artifacts, drive the real
mguard CLI commands through click's runner, and inspect report.json. They skip
when no local chain is listening on DEFAULT_RPC.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest
from click.testing import CliRunner
from eth_account import Account
from mguard import chain as chain_mod
from mguard.main import DEFAULT_RPC, check, migrate, seed
from web3 import Web3

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = REPO_ROOT / "out"

ARTIFACTS = {
    "RegistryV1": "RegistryV1.sol/RegistryV1.json",
    "RegistryV2": "RegistryV2.sol/RegistryV2.json",
    "Migrator": "Migrator.sol/Migrator.json",
    "BuggyMigrator": "BuggyMigrator.sol/BuggyMigrator.json",
}

ZERO = "0x" + "00" * 20
# enum BugMode { None, DropLast, ResetExpiry, SwapOwners, PhantomRecord }
MODE_INDEX = {
    "none": 0,
    "drop-last": 1,
    "reset-expiry": 2,
    "swap-owners": 3,
    "phantom": 4,
}


def _w3() -> Web3 | None:
    """Return a connected Web3, or None when Anvil is not running."""
    try:
        w3 = Web3(Web3.HTTPProvider(DEFAULT_RPC, request_kwargs={"timeout": 5}))
        _probe = w3.eth.chain_id  # connection probe; skip the module when it fails
        del _probe
    except Exception:  # noqa: BLE001 — any failure here means "skip the tests"
        return None
    return w3 if w3.eth.chain_id == chain_mod.LOCAL_CHAIN_ID else None


@pytest.fixture()
def w3() -> Web3:
    web3 = _w3()
    if web3 is None:
        pytest.skip("no local Anvil chain on DEFAULT_RPC")
    return web3


def _sender() -> str:
    return Web3.to_checksum_address(
        Account.from_key(chain_mod.ANVIL_DEFAULT_KEY).address
    )


def _artifact(contract: str) -> dict[str, Any]:
    return json.loads((OUT_DIR / ARTIFACTS[contract]).read_text(encoding="utf-8"))


def _deploy(w3: Web3, contract: str, *args: Any) -> str:
    """Deploy one contract from its forge artifact; returns the checksum address."""
    artifact = _artifact(contract)
    factory = w3.eth.contract(
        abi=artifact["abi"], bytecode=artifact["bytecode"]["object"]
    )
    sender = _sender()
    tx = factory.constructor(*args).build_transaction(
        {
            "from": sender,
            "nonce": w3.eth.get_transaction_count(sender),
            "gas": 5_000_000,
            "chainId": w3.eth.chain_id,
        }
    )
    signed = w3.eth.account.sign_transaction(tx, chain_mod.ANVIL_DEFAULT_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(
        tx_hash, timeout=60, poll_latency=0.05
    )
    assert receipt["status"] == 1
    return Web3.to_checksum_address(receipt["contractAddress"])


@pytest.fixture()
def seeded_v1(w3: Web3) -> str:
    """A fresh RegistryV1 seeded with the ten demo records via the real CLI."""
    v1 = _deploy(w3, "RegistryV1", _sender())
    runner = CliRunner()
    result = runner.invoke(
        seed, ["--rpc", DEFAULT_RPC, "--v1", v1], catch_exceptions=True
    )
    assert result.exit_code == 0, result.output
    return v1


def _deploy_pair(w3: Web3, v1: str, mode: str) -> tuple[str, str]:
    """Deploy (v2, migrator) as an honest pair, or (v2, buggy) for a bug mode.

    Both arrive unwired, like the Deploy script leaves them; the CLI does the
    one-time wiring (and for bug modes, the setMode) itself.
    """
    v2 = _deploy(w3, "RegistryV2", _sender())
    if mode == "honest":
        migrator = _deploy(w3, "Migrator", v1, v2)
        return v2, migrator
    buggy = _deploy(w3, "BuggyMigrator", v1, v2, 0)  # mode None; CLI sets the bug
    return v2, buggy


def test_cli_reads_all_records_from_seeded_v1(w3: Web3, seeded_v1: str) -> None:
    """T2.1 acceptance: reading every record works against Anvil."""
    records = chain_mod.read_registry_v1(w3, seeded_v1)
    assert len(records) == 10
    assert records[0].label == "alice"
    assert all(record.owner != ZERO for record in records)


def test_honest_migration_all_invariants_pass(
    w3: Web3, seeded_v1: str, tmp_path: Path
) -> None:
    v2, migrator = _deploy_pair(w3, seeded_v1, "honest")
    runner = CliRunner()

    result = runner.invoke(
        migrate,
        ["--rpc", DEFAULT_RPC, "--v2", v2, "--migrator", migrator, "--mode", "honest"],
        catch_exceptions=True,
    )
    assert result.exit_code == 0, result.output

    result = runner.invoke(
        check,
        [
            "--rpc",
            DEFAULT_RPC,
            "--v1",
            seeded_v1,
            "--v2",
            v2,
            "--out",
            str(tmp_path / "report.json"),
        ],
        catch_exceptions=True,
    )
    assert result.exit_code == 0, result.output
    report = json.loads((tmp_path / "report.json").read_text(encoding="utf-8"))
    assert all(item["status"] == "PASS" for item in report["invariants"])
    assert report["countV1"] == 10 and report["countV2"] == 10


@pytest.mark.parametrize(
    "mode,invariant",
    [
        ("drop-last", "I3"),
        ("reset-expiry", "I2"),
        ("swap-owners", "I1"),
        ("phantom", "I4"),
    ],
)
def test_every_bug_mode_fails_its_invariant(
    w3: Web3, seeded_v1: str, mode: str, invariant: str, tmp_path: Path
) -> None:
    v2, buggy = _deploy_pair(w3, seeded_v1, mode)
    runner = CliRunner()

    result = runner.invoke(
        migrate,
        [
            "--rpc",
            DEFAULT_RPC,
            "--v2",
            v2,
            "--buggy",
            buggy,
            "--mode",
            mode,
        ],
        catch_exceptions=True,
    )
    assert result.exit_code == 0, result.output

    result = runner.invoke(
        check,
        [
            "--rpc",
            DEFAULT_RPC,
            "--v1",
            seeded_v1,
            "--v2",
            v2,
            "--out",
            str(tmp_path / "report.json"),
        ],
        catch_exceptions=True,
    )
    assert result.exit_code == 1, result.output  # failing invariant -> exit 1
    report = json.loads((tmp_path / "report.json").read_text(encoding="utf-8"))
    failed = [item for item in report["invariants"] if item["status"] == "FAIL"]
    assert invariant in [item["id"] for item in failed]
    assert failed[0]["offenders"], "offending records must be named"


def test_check_empty_pair_writes_report_and_passes(w3: Web3, tmp_path: Path) -> None:
    v1 = _deploy(w3, "RegistryV1", _sender())
    v2 = _deploy(w3, "RegistryV2", _sender())
    runner = CliRunner()
    result = runner.invoke(
        check,
        [
            "--rpc",
            DEFAULT_RPC,
            "--v1",
            v1,
            "--v2",
            v2,
            "--out",
            str(tmp_path / "report.json"),
        ],
        catch_exceptions=True,
    )
    assert result.exit_code == 0, result.output
    assert (tmp_path / "report.json").exists()
    report = json.loads((tmp_path / "report.json").read_text(encoding="utf-8"))
    assert all(item["status"] == "PASS" for item in report["invariants"])
