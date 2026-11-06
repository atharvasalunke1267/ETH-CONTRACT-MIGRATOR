# MigrateGuard — Architecture

### Components

- RegistryV1: name to (label, owner, expiry), enumerable by index.
- RegistryV2: new structure with (label, owner, expiry, migratedAt), writable only by the Migrator.
- Migrator: reads v1, writes v2 in batches, idempotent.
- BuggyMigrator: same interface with a BugMode enum.
- mguard (Python CLI): independent checker that reads both registries through view calls and never trusts the Migrator.
- UI: static page that loads report.json.

### Data flow

```
seed -> RegistryV1 -> Migrator (honest or buggy) -> RegistryV2
            |                                           |
            +------------- mguard check <---------------+
                               |
                           report.json -> UI
```

### Contract interfaces (sketch)

- RegistryV1: register(label, owner, expiry) onlyOwner; recordCount(); keyAt(i); get(key) returns label, owner, expiry.
- RegistryV2: setMigrator(addr) onlyOwner and only once; migrateIn(key, label, owner, expiry) onlyMigrator; recordCount(); keyAt(i); get(key) returns label, owner, expiry, migratedAt.
- Migrator: migrateBatch(start, count) onlyOwner; emits Migrated(key).
- Keys are keccak256 of the label.

### Report shape (pseudo-schema)

```
Report {
  generatedAt, network, v1Address, v2Address,
  countV1, countV2,
  invariants: [ { id, name, status: PASS|FAIL, offenders: [key] } ],
  records: [ { key, label, v1: {owner, expiry}, v2: {owner, expiry} | null,
               status: OK|MISMATCH|MISSING|PHANTOM } ]
}
```

### Repo layout

```
migrateguard/
  src/        RegistryV1.sol RegistryV2.sol Migrator.sol BuggyMigrator.sol
  test/       unit, fuzz, access-control tests
  script/     Deploy.s.sol Seed.s.sol
  cli/mguard/ chain.py invariants.py report.py main.py
  cli/tests/
  ui/         index.html style.css app.js report.sample.json
  PRD.md ARCHITECTURE.md WORKFLOW.md DEPENDENCIES.md
  MEMORY.md RULES.md DESIGN.md TASKS.md README.md
  opencode.json .env.example .gitignore foundry.toml
```

### Key decisions

- The checker lives off-chain in Python so it is independent from the code under test.
- Foundry fuzz tests prove the honest Migrator satisfies the invariants for random record sets.
- Small data (10 to 50 records) keeps loops and gas low.
