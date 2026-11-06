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

- Phase: 5
- Last completed task: T5.1 (README written) + T5.2 scaffold + Phase 4 UI built; forge test 29/29 and pytest 16/16 green
- Blockers: Phase 3 (Sepolia) and T5.3 (GitHub push) need the owner's wallet/credentials; T4.2 needs one browser pass

### Deployed addresses (fill after deployment)

- RegistryV1: TBD (local Anvil 2025-11-06: 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707)
- RegistryV2: TBD (local Anvil: 0x0165878A594ca255338adfa4d48449f69242Eb8F)
- Migrator: TBD (local Anvil: 0xa513E6E4b8f2a923D98304ec87F64353C4D5C853)
- BuggyMigrator: TBD (local Anvil: 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6)

### Commands

- forge build / forge test -vv
- anvil
- pytest cli/tests
- python -m mguard.main check --rpc URL --v1 ADDR --v2 ADDR

### Gotchas (add as discovered)

- Sepolia needs test ETH; faucets can be slow.
- Do not paste private keys into chat or logs.
- Windows: running foundryup inside Git Bash/WSL installs linux binaries. Install the
  `foundry_v<ver>_win32_amd64.zip` asset from the foundry GitHub releases instead
  (verify the .sha256), extract to C:\Users\.foundry\bin and add to PATH.
- forge writes drafts to broadcast\<Script>\<chainId>\run-latest.json (no "latest" folder).
