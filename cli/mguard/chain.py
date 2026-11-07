"""Chain access for mguard.

Everything the checker knows about the contracts comes from ordinary view calls
here; it never trusts the Migrator or queries it at all (decision D1).
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from dotenv import load_dotenv
from eth_account import Account
from web3 import Web3
from web3.providers import HTTPProvider

ANVIL_DEFAULT_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
MAINNET_CHAIN_ID = 1
LOCAL_CHAIN_ID = 31337

MAX_BATCH_SIZE = 100
ZERO_ADDRESS = "0x" + "00" * 20


def _fn(
    name: str,
    inputs: list[dict[str, str]],
    outputs: list[dict[str, str]],
    *,
    view: bool = True,
) -> dict[str, Any]:
    """Shorthand for a named ABI function entry."""
    return {
        "name": name,
        "type": "function",
        "stateMutability": "view" if view else "nonpayable",
        "inputs": inputs,
        "outputs": outputs,
    }


_UINT = {"type": "uint256"}
_BYTE = {"type": "bytes32"}
_BOOL = {"type": "bool"}
_STRING = {"type": "string"}
_ADDR = {"type": "address"}
_U64 = {"type": "uint64"}
_U8 = {"type": "uint8"}

V1_ABI = [
    _fn("recordCount", [], [_UINT]),
    _fn("keyAt", [{"name": "index", "type": "uint256"}], [_BYTE]),
    _fn("get", [{"name": "key", "type": "bytes32"}], [_STRING, _ADDR, _U64]),
    _fn("has", [{"name": "key", "type": "bytes32"}], [_BOOL]),
]

V2_ABI = [
    _fn("recordCount", [], [_UINT]),
    _fn("keyAt", [{"name": "index", "type": "uint256"}], [_BYTE]),
    _fn("get", [{"name": "key", "type": "bytes32"}], [_STRING, _ADDR, _U64, _U64]),
    _fn("has", [{"name": "key", "type": "bytes32"}], [_BOOL]),
    _fn("migrator", [], [_ADDR]),
]

REGISTER_ABI = [
    _fn(
        "register",
        [
            {"name": "label", "type": "string"},
            {"name": "owner_", "type": "address"},
            {"name": "expiry", "type": "uint64"},
        ],
        [_BYTE],
        view=False,
    ),
    _fn("has", [{"name": "key", "type": "bytes32"}], [_BOOL]),
]

SET_MIGRATOR_ABI = [
    _fn("setMigrator", [{"name": "migrator_", "type": "address"}], [], view=False),
    _fn("migrator", [], [_ADDR]),
]

MIGRATE_BATCH_ABI = [
    _fn(
        "migrateBatch",
        [
            {"name": "start", "type": "uint256"},
            {"name": "count", "type": "uint256"},
        ],
        [],
        view=False,
    ),
    _fn("v1", [], [_ADDR]),
    _fn("v2", [], [_ADDR]),
]

BUGGY_MODE_ABI = [
    _fn("mode", [], [_U8]),
    _fn("setMode", [{"name": "mode_", "type": "uint8"}], [], view=False),
]


class ChainError(Exception):
    """Raised when reading from the chain fails (maps to exit code 2)."""


class MainnetForbidden(ChainError):
    """Raised when a config points at mainnet — never allowed."""


@dataclass(frozen=True)
class V1Record:
    """A record read from RegistryV1."""

    key: str
    label: str
    owner: str
    expiry: int


@dataclass(frozen=True)
class V2Record:
    """A record read from RegistryV2."""

    key: str
    label: str
    owner: str
    expiry: int
    migrated_at: int


def connect(rpc_url: str) -> Web3:
    """Connect to an RPC endpoint and refuse mainnet (security rule)."""
    w3 = Web3(HTTPProvider(rpc_url, request_kwargs={"timeout": 30}))
    try:
        chain_id = w3.eth.chain_id
    except Exception as error:
        raise ChainError(f"cannot reach RPC {rpc_url!r}: {error}") from error
    if chain_id == MAINNET_CHAIN_ID:
        raise MainnetForbidden(
            "refusing to run against mainnet; use a testnet or local chain only"
        )
    return w3


def load_private_key(w3: Web3) -> str:
    """Return a private key for signing, never printing it.

    The public Anvil dev key is used for a 31337 local chain so a stray .env
    cannot shadow the local deployer; Sepolia and other chains must supply
    PRIVATE_KEY through .env (loaded but never echoed).
    """
    if w3.eth.chain_id == LOCAL_CHAIN_ID:
        return ANVIL_DEFAULT_KEY
    env_key = _env_private_key()
    if env_key:
        return env_key
    raise ChainError(
        "no PRIVATE_KEY configured for this network; set it in .env (testnet-only wallet)"
    )


def _env_private_key() -> str | None:
    """Read PRIVATE_KEY from the environment/.env without echoing it."""
    load_dotenv()
    return os.environ.get("PRIVATE_KEY") or None


def read_registry_v1(w3: Web3, address: str) -> list[V1Record]:
    """Read every record from RegistryV1 by enumeration (T2.1)."""
    contract = w3.eth.contract(address=Web3.to_checksum_address(address), abi=V1_ABI)
    try:
        count = int(contract.functions.recordCount().call())
        records: list[V1Record] = []
        for index in range(count):
            key = contract.functions.keyAt(index).call()
            label, owner, expiry = contract.functions.get(key).call()
            records.append(
                V1Record(
                    key=hex_key(key),
                    label=str(label),
                    owner=Web3.to_checksum_address(owner),
                    expiry=int(expiry),
                )
            )
    except ChainError:
        raise
    except Exception as error:
        raise ChainError(f"failed reading RegistryV1 {address}: {error}") from error
    return records


def read_registry_v2(w3: Web3, address: str) -> list[V2Record]:
    """Read every record from RegistryV2 by enumeration (T2.1)."""
    contract = w3.eth.contract(address=Web3.to_checksum_address(address), abi=V2_ABI)
    try:
        count = int(contract.functions.recordCount().call())
        records: list[V2Record] = []
        for index in range(count):
            key = contract.functions.keyAt(index).call()
            label, owner, expiry, migrated_at = contract.functions.get(key).call()
            records.append(
                V2Record(
                    key=hex_key(key),
                    label=str(label),
                    owner=Web3.to_checksum_address(owner),
                    expiry=int(expiry),
                    migrated_at=int(migrated_at),
                )
            )
    except ChainError:
        raise
    except Exception as error:
        raise ChainError(f"failed reading RegistryV2 {address}: {error}") from error
    return records


def send_transaction(
    w3: Web3,
    address: str,
    abi: list[dict[str, Any]],
    function: str,
    args: tuple[Any, ...],
    private_key: str,
) -> str:
    """Sign, send, and wait for one state-changing call. Returns the tx hash."""
    contract = w3.eth.contract(address=Web3.to_checksum_address(address), abi=abi)
    account = Account.from_key(private_key)
    try:
        call = contract.get_function_by_name(function)(*args)
        gas = call.estimate_gas({"from": account.address})
        tx = call.build_transaction(
            {
                "from": Web3.to_checksum_address(account.address),
                "nonce": w3.eth.get_transaction_count(
                    Web3.to_checksum_address(account.address)
                ),
                "gas": int(gas * 1.2) + 21_000,
                "chainId": w3.eth.chain_id,
            }
        )
        signed = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
        w3.eth.wait_for_transaction_receipt(tx_hash, timeout=120, poll_latency=0.2)
        return tx_hash.hex()
    except ChainError:
        raise
    except Exception as error:
        raise ChainError(f"transaction {function} failed: {error}") from error


def label_key(label: str) -> str:
    """Compute a registry key: keccak256(bytes(label)) — the v1 key scheme."""
    return "0x" + Web3.keccak(text=label).hex()


def hex_key(raw: bytes | bytearray | str) -> str:
    """Normalize a bytes32 into a 0x-prefixed lowercase hex string."""
    if isinstance(raw, str):
        return raw.lower()
    return "0x" + bytes(raw).hex()
