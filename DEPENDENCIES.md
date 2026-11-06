# MigrateGuard — Dependencies

| Tool | Target version | Use |
| --- | --- | --- |
| Foundry (forge, cast, anvil) | latest stable | Contracts, tests, local chain |
| Solidity | 0.8.24 | Contracts |
| forge-std | latest | Test helpers |
| Python | 3.11+ | CLI |
| web3.py | 7.x | Chain reads |
| click | 8.x | CLI framework |
| rich | 13.x | Terminal output |
| python-dotenv | 1.x | Load .env |
| pytest | 8.x | CLI tests |
| ruff | latest | Lint and format |
| Node.js | 20+ | Needed only to run opencode |
| MetaMask | n/a | Wallet for Sepolia |

No OpenZeppelin on purpose: the registries use a tiny custom onlyOwner so the code stays readable and easy to explain.

### Setup checklist

- Install Foundry and run forge init.
- Create a Python venv and pip install web3 click rich python-dotenv pytest ruff.
- Create a fresh dev wallet used only for testnet. Get Sepolia ETH from a faucet.
- Copy .env.example to .env and fill SEPOLIA_RPC_URL and PRIVATE_KEY. Never commit .env.
