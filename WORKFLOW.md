# MigrateGuard — Workflow

### Development loop (one task at a time)

1. Read the next unchecked task in TASKS.md.
2. Plan in a few lines (use opencode Plan mode first).
3. Write the test, then the code.
4. Run forge test or pytest.
5. Commit with a message like feat(registry): add RegistryV1.
6. Tick the task and update MEMORY.md.
7. Stop and report. Do not start the next task unasked.

### Demo flow

1. Start Anvil, or use Sepolia with .env set.
2. Deploy: forge script script/Deploy.s.sol.
3. mguard seed creates 10 sample records in v1.
4. mguard migrate --mode honest, then mguard check. All PASS.
5. Redeploy a fresh v2. mguard migrate --mode swap-owners, then mguard check. I1 FAILS and names the records.
6. Repeat for drop-last, reset-expiry, phantom.
7. Open ui/index.html to show the report.

### Git

Branch per phase (phase-1-contracts, and so on). Small commits. Push to GitHub at the end of each day.
