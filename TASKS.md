# MigrateGuard — Tasks

Tick a box only when its acceptance criteria are met and tests pass.

### Phase 0: Setup

- [x] T0.1 Init Foundry project, add folders from ARCHITECTURE.md. Done when forge build succeeds.
- [x] T0.2 Python venv and cli/mguard skeleton with click. Done when mguard --help runs.
- [x] T0.3 .gitignore (includes .env), .env.example, README stub. Done when git status shows no secrets.

### Phase 1: Contracts

- [x] T1.1 RegistryV1 with tests. Done when register, get, enumeration and onlyOwner are tested.
- [x] T1.2 RegistryV2 with tests. Done when only the migrator can write (I6).
- [x] T1.3 Migrator (honest) with tests. Done when I1 to I5 hold on sample data.
- [x] T1.4 BuggyMigrator with four modes. Done when each mode has a test that breaks the matching invariant.
- [x] T1.5 Fuzz tests. Done when random record sets pass I1 to I5 with the honest Migrator.
- [x] T1.6 Deploy and Seed scripts. Done when they run on local Anvil.

### Phase 2: CLI

- [ ] T2.1 chain.py: read all records from a registry. Done when it works against Anvil.
- [ ] T2.2 invariants.py: I1 to I4 on plain data. Done when pytest covers pass and fail cases without a chain.
- [ ] T2.3 report.py and check command. Done when report.json is written and the exit code is correct.
- [ ] T2.4 seed and migrate commands with --mode. Done when the full demo runs on Anvil.
- [ ] T2.5 End-to-end pytest on Anvil. Done when honest passes and all four buggy modes fail.

### Phase 3: Sepolia

- [ ] T3.1 Deploy to Sepolia and record addresses in MEMORY.md.
- [ ] T3.2 Run honest and buggy demos on Sepolia. Save the tx links in the README.

### Phase 4: UI

- [ ] T4.1 Static page renders report.sample.json following DESIGN.md.
- [ ] T4.2 Load a real report.json. Check responsive layout and accessibility rules.

### Phase 5: Wrap-up

- [ ] T5.1 README: what it does, how it works, how to run, limits.
- [ ] T5.2 Personal notes file: what you learned each day (your documentation).
- [ ] T5.3 Push to GitHub. Rehearse the demo twice.

### Schedule

- Wed 4 Nov night: Phase 0, T1.1, T1.2.
- Thu 5 Nov: rest of Phase 1, Phase 2.
- Fri 6 Nov: Phases 3 to 5.
- Sat 7 Nov: review meet.

### Cut line if time runs short

Keep Phase 0, T1.1 to T1.4, and a manual check in Remix or cast. Drop the UI first, then Sepolia, then fuzz tests.
