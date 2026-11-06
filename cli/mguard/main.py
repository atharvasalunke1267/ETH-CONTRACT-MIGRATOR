"""CLI entry point for mguard (FR5-FR7).

Commands:
  mguard seed    --rpc R --v1 ADDR
  mguard migrate --rpc R --v2 ADDR [--migrator|--buggy] ADDR --mode [...]
  mguard check   --rpc R --v1 ADDR --v2 ADDR [--out report.json]

Exit codes (FR6): 0 pass, 1 invariant failure, 2 usage or connection error.
"""

from __future__ import annotations

from pathlib import Path

import click
from rich.console import Console
from rich.table import Table
from web3 import Web3

from mguard import chain as chain_mod
from mguard import invariants as invariant_mod
from mguard import report as report_mod
from mguard import samples as samples_mod
from mguard.invariants import InvariantResult

console = Console()

DEFAULT_RPC = "http://127.0.0.1:8545"

MODES = ("honest", "drop-last", "reset-expiry", "swap-owners", "phantom")

ZERO_ADDRESS = "0x" + "00" * 20


@click.group(help="MigrateGuard: verify a v1 -> v2 registry migration.")
def main() -> None:
    """mguard — check that a contract migration preserved every invariant."""


@main.command("seed")
@click.option(
    "--rpc", default=DEFAULT_RPC, show_default=True, help="JSON-RPC endpoint."
)
@click.option("--v1", "v1_address", required=True, help="RegistryV1 address.")
@click.option(
    "--count",
    default=len(samples_mod.DEMO_LABELS),
    show_default=True,
    help="How many of the ten demo records to register.",
)
@click.pass_context
def seed(ctx: click.Context, rpc: str, v1_address: str, count: int) -> None:
    """Register the sample demo records in RegistryV1 (FR7)."""
    try:
        w3 = chain_mod.connect(rpc)
        key = chain_mod.load_private_key(w3)
        contract = w3.eth.contract(
            address=Web3.to_checksum_address(v1_address), abi=chain_mod.REGISTER_ABI
        )
        records = samples_mod.demo_records()[
            : max(0, min(count, len(samples_mod.DEMO_LABELS)))
        ]
        for sample in records:
            key_hex = chain_mod.label_key(sample.label)
            if contract.functions.has(key_hex).call():
                console.print(f"skip {sample.label} (already registered)")
                continue
            tx_hash = chain_mod.send_transaction(
                w3,
                v1_address,
                chain_mod.REGISTER_ABI,
                "register",
                (sample.label, sample.owner, sample.expiry),
                key,
            )
            console.print(f"registered {sample.label} tx {tx_hash[:10]}…")
        console.print(
            f"[green]seed complete[/green]: from set of {len(records)} demo records"
        )
    except chain_mod.ChainError as error:
        ctx.exit(2, str(error))
        return
    ctx.exit(0)


@main.command("migrate")
@click.option(
    "--rpc", default=DEFAULT_RPC, show_default=True, help="JSON-RPC endpoint."
)
@click.option(
    "--v2", "v2_address", required=True, help="RegistryV2 address to migrate into."
)
@click.option(
    "--migrator",
    "migrator_address",
    default=None,
    help="Honest Migrator address (required when --mode honest).",
)
@click.option("--buggy", "buggy_address", default=None, help="BuggyMigrator address.")
@click.option(
    "--mode",
    "mode",
    default="honest",
    show_default=True,
    type=click.Choice(MODES),
    help="honest runs the real Migrator; anything else drives the BuggyMigrator.",
)
@click.option(
    "--batch",
    "batch_size",
    default=5,
    show_default=True,
    help="Records per batch call.",
)
@click.pass_context
def migrate(
    ctx: click.Context,
    rpc: str,
    v2_address: str,
    migrator_address: str | None,
    buggy_address: str | None,
    mode: str,
    batch_size: int,
) -> None:
    """Run a migration (honest or buggy) against RegistryV2 (FR2, FR4)."""
    try:
        w3 = chain_mod.connect(rpc)
        key = chain_mod.load_private_key(w3)
        chosen = migrator_address if mode == "honest" else buggy_address

        if chosen is None:
            console.print(
                "[red]error:[/red] --migrator ADDR is required for --mode honest; "
                "--buggy ADDR is required for buggy modes"
            )
            ctx.exit(2)
            return

        _ensure_migrator_wired(w3, v2_address, chosen, key)
        if mode != "honest":
            _ensure_bug_mode(w3, chosen, mode, key)

        total = _migrateable_count(w3, chosen)
        rate = max(1, min(batch_size, chain_mod.MAX_BATCH_SIZE))
        done = 0
        while done < total:
            start, count = done, min(rate, total - done)
            tx_hash = chain_mod.send_transaction(
                w3,
                chosen,
                chain_mod.MIGRATE_BATCH_ABI,
                "migrateBatch",
                (start, count),
                key,
            )
            done += count
            console.print(
                f"batch [{start}..{start + count}) done ({done}/{total}) tx {tx_hash[:10]}…"
            )
        console.print(
            f"[green]migration complete[/green]: mode={mode}, {total} records handled"
        )
        ctx.exit(0)
    except chain_mod.ChainError as error:
        ctx.exit(2, str(error))


def _migrateable_count(w3: Web3, migrator_address: str) -> int:
    """How many records live in the v1 registry the selected migrator points at?"""
    migrator = w3.eth.contract(
        address=Web3.to_checksum_address(migrator_address),
        abi=chain_mod.MIGRATE_BATCH_ABI,
    )
    registry = w3.eth.contract(
        address=Web3.to_checksum_address(migrator.functions.v1().call()),
        abi=chain_mod.V1_ABI,
    )
    return int(registry.functions.recordCount().call())


def _ensure_migrator_wired(w3: Web3, v2_address: str, chosen: str, key: str) -> None:
    """Point v2 at the selected migrator if it is not wired yet (one-time)."""
    v2 = w3.eth.contract(
        address=Web3.to_checksum_address(v2_address), abi=chain_mod.SET_MIGRATOR_ABI
    )
    current = _address_hex(v2.functions.migrator().call())
    if current == ZERO_ADDRESS:
        tx_hash = chain_mod.send_transaction(
            w3,
            v2_address,
            chain_mod.SET_MIGRATOR_ABI,
            "setMigrator",
            (Web3.to_checksum_address(chosen),),
            key,
        )
        console.print(f"wired migrator -> tx {tx_hash[:10]}…")
    elif current.lower() != chosen.lower():
        raise chain_mod.ChainError(
            "v2 migrator is already set and cannot be changed; deploy a fresh "
            "RegistryV2 for this run (see README demo flow)"
        )


def _ensure_bug_mode(w3: Web3, buggy_address: str, mode: str, key: str) -> None:
    """Make the BuggyMigrator run the requested bug (one-time setMode)."""
    mode_index = {
        "none": 0,
        "drop-last": 1,
        "reset-expiry": 2,
        "swap-owners": 3,
        "phantom": 4,
    }[mode]
    buggy = w3.eth.contract(
        address=Web3.to_checksum_address(buggy_address), abi=chain_mod.BUGGY_MODE_ABI
    )
    current = int(buggy.functions.mode().call())
    if current == 0 and mode_index != 0:
        tx_hash = chain_mod.send_transaction(
            w3, buggy_address, chain_mod.BUGGY_MODE_ABI, "setMode", (mode_index,), key
        )
        console.print(f"bug mode set to {mode} -> tx {tx_hash[:10]}…")
    elif current != mode_index:
        raise chain_mod.ChainError(
            f"this BuggyMigrator is already fixed to mode {current}; "
            "deploy a fresh BuggyMigrator to switch bugs"
        )


def _address_hex(raw: str | bytes | bytearray) -> str:
    """Normalize an address output to a lowercase 0x-prefixed string."""
    if isinstance(raw, (bytes, bytearray)):
        return "0x" + bytes(raw).hex()
    return str(raw).lower()


@main.command("check")
@click.option(
    "--rpc", default=DEFAULT_RPC, show_default=True, help="JSON-RPC endpoint."
)
@click.option("--v1", "v1_address", required=True, help="RegistryV1 address.")
@click.option("--v2", "v2_address", required=True, help="RegistryV2 address.")
@click.option(
    "--out",
    "out_path",
    default="report.json",
    show_default=True,
    type=click.Path(path_type=Path),
    help="Where to write report.json.",
)
@click.pass_context
def check(
    ctx: click.Context, rpc: str, v1_address: str, v2_address: str, out_path: Path
) -> None:
    """Read both registries, evaluate I1-I4, and write report.json (FR5, FR6)."""
    try:
        w3 = chain_mod.connect(rpc)
        v1_records = chain_mod.read_registry_v1(w3, v1_address)
        v2_records = chain_mod.read_registry_v2(w3, v2_address)
    except chain_mod.ChainError as error:
        ctx.exit(2, str(error))

    results, rows = invariant_mod.evaluate_invariants(v1_records, v2_records)
    report = report_mod.build_report(
        network_id=int(w3.eth.chain_id),
        v1_address=v1_address,
        v2_address=v2_address,
        v1_records=v1_records,
        v2_records=v2_records,
        invariants=results,
        records=rows,
    )
    try:
        written = report_mod.save_report(report, out_path)
    except OSError as error:
        console.print(f"[red]error:[/red] cannot write report to {out_path}: {error}")
        ctx.exit(2)
        return

    _print_invariants(results)
    console.print(f"report written to {written}")
    failed = sum(1 for item in results if item.status == "FAIL")
    console.print(f"{len(results) - failed} of {len(results)} invariants passed")
    ctx.exit(0 if not failed else 1)


def _print_invariants(results: list[InvariantResult]) -> None:
    """Rich table: one row per invariant, offenders named."""
    table = Table(title="MigrateGuard invariant check")
    table.add_column("id", style="bold")
    table.add_column("invariant")
    table.add_column("status")
    table.add_column("offenders")
    for item in results:
        offenders = ", ".join(_short(key) for key in item.offenders)
        style = "green" if item.status == "PASS" else "red"
        table.add_row(
            item.id, item.name, f"[{style}]{item.status}[/{style}]", offenders
        )
    console.print(table)


def _short(key: str) -> str:
    """0x1234…abcd display form for long hex keys."""
    if len(key) > 14:
        return f"{key[:6]}…{key[-4:]}"
    return key


if __name__ == "__main__":
    main()
