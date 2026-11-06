# MigrateGuard — Memory

### Project

MigrateGuard: migrates records from RegistryV1 to RegistryV2 and checks invariants I1 to I6. A buggy migrator proves the checker catches errors. Built for the ETH VJTI Devcon 8 requirement. Review meet: 7 Nov 2026.

### Owner context

First-year IT student, new to web3, strong in C++ and DSA, growing Python. Explain Solidity concepts briefly when introducing them, comparing to C++ where useful.

### Decisions

- D1: Checker is off-chain Python, independent of the Migrator.
- D2: Foundry for contracts and tests; no Hardhat.
- D3: No OpenZeppelin; custom onlyOwner.
- D4: Sepolia testnet only; Anvil as fallback.
- D5: UI is static HTML reading report.json; no framework.
- D6: Registry is a toy inspired by ENS, not real ENS.

### Current status (agent updates after each task)

- Phase: 0
- Last completed task: none
- Blockers: none

### Deployed addresses (fill after deployment)

- RegistryV1: TBD
- RegistryV2: TBD
- Migrator: TBD
- BuggyMigrator: TBD

### Commands

- forge build / forge test -vv
- anvil
- pytest cli/tests
- python -m mguard.main check --rpc URL --v1 ADDR --v2 ADDR

### Gotchas (add as discovered)

- Sepolia needs test ETH; faucets can be slow.
- Do not paste private keys into chat or logs.
