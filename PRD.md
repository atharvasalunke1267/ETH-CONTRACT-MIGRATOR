# MigrateGuard — PRD

### Problem

Contract migrations are irreversible and error-prone, and teams usually verify them by hand.

### Goal

A small, working tool that migrates records v1 to v2 and proves, with automated checks, that the invariants still hold. It must visibly fail on a broken migration.

### Users

- The developer (you), running the CLI and demo.
- ETH VJTI reviewers, who need to understand it in two minutes.

### Scope (in)

- Toy name registry v1 and v2 contracts on Sepolia.
- An honest Migrator and a BuggyMigrator with four bug modes.
- A Python CLI that reads both registries and reports invariant results.
- Foundry tests including fuzz tests.
- A static HTML report page.

### Out of scope

ZK proofs, mainnet, upgradeable proxies, real ENS integration, wallets in the UI, token economics.

### Invariants

| ID | Name | Rule | Caught by |
| --- | --- | --- | --- |
| I1 | Ownership preserved | Every v1 record has the same owner in v2 | SwapOwners bug |
| I2 | Expiry preserved | Same expiry, so expired stays expired | ResetExpiry bug |
| I3 | No record lost | Every v1 key exists in v2 | DropLast bug |
| I4 | No phantom records | v2 holds no key absent from v1 | PhantomRecord bug |
| I5 | Idempotent | Running migration twice changes nothing | Foundry test |
| I6 | Access control | Only the Migrator can write to v2 | Foundry test |

### Functional requirements

- FR1: Owner can register records in v1 (label, owner, expiry).
- FR2: Owner can run migrateBatch(start, count) on a Migrator.
- FR3: The honest Migrator copies records exactly and skips already-migrated ones.
- FR4: The BuggyMigrator supports DropLast, ResetExpiry, SwapOwners, PhantomRecord.
- FR5: CLI command check reads both registries and evaluates I1 to I4.
- FR6: CLI exits with code 0 on pass and 1 on any failure, and writes report.json.
- FR7: CLI commands seed and migrate drive the demo end to end.
- FR8: The UI renders report.json as a before/after view with pass/fail status.

### Non-functional requirements

- Works on a local Anvil chain and on Sepolia.
- Demo data is 10 records, batch size 5.
- No secret ever committed.
- Setup from clean clone in under 15 minutes using the README.

### Success criteria

- Honest migration: all invariants PASS.
- Each of the four bug modes: at least one invariant FAILS with the offending records named.
- You can explain it unaided on 7 Nov.

### Risks

- Scope creep. Mitigation: follow the cut line in TASKS.md.
- Testnet faucet or RPC trouble. Mitigation: Anvil local demo as fallback.
