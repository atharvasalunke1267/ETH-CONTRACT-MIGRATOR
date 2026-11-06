"""mguard: the MigrateGuard off-chain invariant checker.

Reads RegistryV1 and RegistryV2 through ordinary view calls and never
trusts the on-chain Migrator. A rule that must always be true after a
migration is called an invariant (see invariants.py).
"""

__version__ = "0.1.0"
