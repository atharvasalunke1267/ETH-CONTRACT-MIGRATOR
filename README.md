# MigrateGuard

Migrates records from a toy RegistryV1 to RegistryV2 on an Ethereum chain, then
independently verifies — with an off-chain Python checker — that nothing was
lost, altered, or invented. A deliberately buggy migrator proves the checker
catches each mistake.

**The problem it answers.** Smart contracts cannot be edited after deployment.
When a team ships a new version, it must copy the old data into the new one. If
the copy is wrong — one owner changed, one record lost — there is no undo.
MigrateGuard makes the copy provably correct, or visibly wrong.

Analogy: moving a bank's accounts to new software, then reconciling every
account to confirm nothing was lost or changed.

Built for the ETH VJTI Devcon 8 requirement (review meet: 7 Nov 2026).

---

## How it works

```
seed -> RegistryV1 -> Migrator (honest or buggy) -> RegistryV2
            |                                           |
            +------------- mguard check <---------------+
                               |
                           report.json -> ui/index.html
```

| Piece | File | Role |
| --- | --- | --- |
| RegistryV1 | `src/RegistryV1.sol` | toy name registry: label -> (owner, expiry), enumerable |
| RegistryV2 | `src/RegistryV2.sol` | new shape: adds `migratedAt`; writable only by a trusted migrator |
| Migrator | `src/Migrator.sol` | honest batch copy, idempotent (I5) |
| BuggyMigrator | `src/BuggyMigrator.sol` | four bug modes, each designed to break one invariant |
| mguard CLI | `cli/mguard/` | independent off-chain checker: reads both registries, writes `report.json` |
| UI | `ui/index.html` | static page rendering the report, no framework, no server |

### Invariants

| ID | Name | Rule | Buggy mode that breaks it |
| --- | --- | --- | --- |
| I1 | Ownership preserved | same owner in v2 for every v1 record | `swap-owners` |
| I2 | Expiry preserved | same expiry, so expired stays expired | `reset-expiry` |
| I3 | No record lost | every v1 key exists in v2 | `drop-last` |
| I4 | No phantom records | v2 holds no key absent from v1 | `phantom` |
| I5 | Idempotent | running migration twice changes nothing | (Foundry test) |
| I6 | Access control | only the Migrator can write to v2 | (Foundry test) |

I1–I4 are checked by the Python CLI; I5–I6 are proven by Foundry tests
(`forge test`), because they are properties of the contract code rather than
of a particular pair of registries.

---

## Quickstart

Prerequisites: [Foundry](https://book.getfoundry.sh/) (forge, anvil) and
Python 3.11+.

```sh
# 1. Build contracts and run the Solidity + fuzz suite
forge build && forge test

# 2. Python environment for the CLI
python -m venv .venv && .venv\Scripts\pip install web3 click rich python-dotenv pytest ruff   # Windows
#  (Linux/macOS: .venv/bin/pip…)  — or see cli/pyproject.toml

# 3. Local chain
anvil    # leave running

# 4. Deploy the demo stack (prints all addresses)
forge script script/Deploy.s.sol --rpc-url anvil --broadcast

# 5. Seed 10 demo records through the CLI (from the cli/ folder)
cd cli
python -m mguard.main seed      --rpc http://127.0.0.1:8545 --v1 <REGISTRY_V1>
python -m mguard.main migrate   --rpc http://127.0.0.1:8545 --v2 <REGISTRY_V2> --migrator <MIGRATOR> --mode honest
python -m mguard.main check     --rpc http://127.0.0.1:8545 --v1 <REGISTRY_V1> --v2 <REGISTRY_V2> --out ../ui/report.json

# 6. Show the report
open ../ui/index.html
```

Exit codes of `mguard check`: **0** all invariants pass, **1** at least one
invariant failed, **2** usage or connection error.

## Buggy demos (the point)

Redeploy a fresh v2 over the same seeded v1, then let the CLI wire the buggy
migrator and inject a bug:

```sh
# fresh v2 + fresh buggy migrator over the same v1
$env:V1_ADDRESS=<REGISTRY_V1>; forge script script/Deploy.s.sol --rpc-url anvil --broadcast

python -m mguard.main migrate --rpc ... --v2 <NEW_V2> --buggy <NEW_BUGGY> --mode swap-owners
python -m mguard.main check  --rpc ... --v1 <REGISTRY_V1> --v2 <NEW_V2> --out ../ui/report.json
# -> I1 FAILS and names the offending records; exit code 1
```

Repeat with `--mode drop-last` (I3), `--mode reset-expiry` (I2), and
`--mode phantom` (I4). The honest mode always passes everything — that
contrast is the demo.

## Sepolia

Sepolia is supported but needs your testnet-only wallet:

```sh
copy .env.example .env   # then fill SEPOLIA_RPC_URL and PRIVATE_KEY (NEVER commit .env)
forge script script/Deploy.s.sol --rpc-url sepolia --broadcast
```

Tx links from the Sepolia demo:

- RegistryV1: TBD
- RegistryV2: TBD
- honest migration tx: TBD
- buggy migration tx: TBD

## Testing

```sh
forge test            # 29 Solidity tests incl. 2 x 256-run fuzz suites
.venv\Scripts\python -m pytest cli/tests   # 16 tests; e2e ones need Anvil running
```

## Limits

- Toy registry inspired by the ENSv2 migration talks — not real ENS.
- Testnet/local only; the checker refuses mainnet chain ids outright.
- No ZK proofs, no upgradeable proxies, no wallets in the UI. A natural next
  step would be a Merkle-root proof over the whole v1 state (see cheat sheet).
- The CLI evaluates I1–I4; I5–I6 live in the Foundry suites.
