# MigrateGuard — Rules

### General

- Follow TASKS.md order. One task at a time. No features outside PRD scope.
- Prefer small, readable code over clever code. This is a learning project.
- Explain new concepts in one or two comments or in the reply.
- Ask before adding any dependency not listed in DEPENDENCIES.md.

### Solidity

- Pin pragma to exactly 0.8.24.
- NatSpec comments on every external function.
- Use custom errors, not revert strings.
- Emit an event for every state change.
- Checks-effects-interactions ordering; no external calls before state updates.
- Forbidden: tx.origin, selfdestruct, delegatecall, inline assembly, unbounded loops in write paths.
- Use uint64 for timestamps, bytes32 for keys.
- Name test files X.t.sol and tests test_ or testFuzz_ with a clear behavior name.

### Python

- Python 3.11+, type hints on all functions, docstrings on public functions.
- Format and lint with ruff before finishing a task.
- No global state; pass RPC URL and addresses as arguments.
- Exit codes: 0 pass, 1 invariant failure, 2 usage or connection error.

### Testing

- Write the test first. A task is not done until forge test or pytest passes.
- Every invariant needs a passing case and a failing case.
- Fuzz tests must run at least 256 runs.

### Security and secrets

- Never read, print, log or commit .env or private keys.
- Never target mainnet. Reject any config pointing to a mainnet chain id.
- Use a testnet-only wallet.

### Git

- Conventional commits: feat, fix, test, docs, chore.
- Never force-push. Never rewrite history.

### Agent behavior

- Show a plan before editing. Keep diffs small.
- After each task: run tests, tick TASKS.md, update MEMORY.md status, then stop.
- If a requirement is unclear, ask one question instead of guessing.
- Never invent contract addresses, versions or command flags. Say when unsure.
- Do not delete files or run destructive shell commands without explicit approval.
