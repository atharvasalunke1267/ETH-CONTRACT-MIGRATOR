// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IRegistryV1Like, IRegistryV2Like} from "./Registries.sol";

/// @title BuggyMigrator — deliberately broken migrations for the demo.
/// @notice Same interface as Migrator plus a BugMode switch. Each mode breaks
///         exactly the invariant it was designed to expose (see TASKS T1.4):
///           DropLast      -> I3 NoRecordLost      (the last v1 key never arrives)
///           ResetExpiry   -> I2 ExpiryPreserved   (expiry becomes 0)
///           SwapOwners    -> I1 OwnershipPreserved(owner is replaced)
///           PhantomRecord -> I4 NoPhantomRecords  (one extra key appears)
contract BuggyMigrator {
    /// @notice The bug to inject in the next migrateBatch call.
    enum BugMode {
        None,
        DropLast,
        ResetExpiry,
        SwapOwners,
        PhantomRecord
    }

    /// @notice Bounded batches, matching the honest Migrator.
    uint256 public constant MAX_BATCH = 100;

    // ── Custom errors ────────────────────────────────────────────────
    error NotBuggyOwner();
    error ModeAlreadyFixed();
    error BatchTooLarge();
    error RangeOutOfBounds();

    // ── Events ───────────────────────────────────────────────────────
    /// @notice A v1 key was written into v2 (possibly corrupted by the active bug).
    event Migrated(bytes32 indexed key);

    address public owner;
    BugMode public mode;
    IRegistryV1Like public immutable v1;
    IRegistryV2Like public immutable v2;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotBuggyOwner();
        _;
    }

    /// @param v1_ the old registry to read from.
    /// @param v2_ the new registry that granted write access to this contract.
    /// @param mode_ the first bug mode to run with (re-settable by the owner).
    constructor(address v1_, address v2_, BugMode mode_) {
        v1 = IRegistryV1Like(v1_);
        v2 = IRegistryV2Like(v2_);
        owner = msg.sender;
        mode = mode_;
    }

    /// @notice Switch the bug that future migrations inject.
    /// @param mode_ one of DropLast, ResetExpiry, SwapOwners, PhantomRecord (or None).
    function setMode(BugMode mode_) external onlyOwner {
        if (mode != BugMode.None) revert ModeAlreadyFixed();
        mode = mode_;
    }

    /// @notice Copy records [start, start+count) from v1 to v2 — with the chosen bug applied.
    /// @param start is the first v1 enumeration index to copy.
    /// @param count is the number of records this bounded batch loop walks.
    function migrateBatch(uint256 start, uint256 count) external onlyOwner {
        if (count > MAX_BATCH) revert BatchTooLarge();
        if (start + count > v1.recordCount()) revert RangeOutOfBounds();

        uint256 end = start + count;
        uint256 last = end - 1;
        // forge-lint: disable-next-line(calls-loop, require-revert-in-loop)
        // The loop is bounded by MAX_BATCH; cross-contract reads/writes are the step.
        for (uint256 i = start; i < end; ++i) {
            bytes32 key = v1.keyAt(i);

            // Idempotent skip keeps the honest framing: the bug is the only difference.
            if (v2.has(key)) continue;
            (string memory label, address owner_, uint64 expiry) = v1.get(key);

            BugMode m = mode;
            if (m == BugMode.DropLast) {
                // Simply never copy the final record of the range (I3).
                if (i == last) continue;
                v2.migrateIn(key, label, owner_, expiry);
            } else if (m == BugMode.ResetExpiry) {
                // Zero the expiry: nothing avoids the expiry change (I2 fails, I1 still passes).
                v2.migrateIn(key, label, owner_, 0);
            } else if (m == BugMode.SwapOwners) {
                // Replace the real owner with a different address (I1).
                v2.migrateIn(key, label, address(this), expiry);
            } else if (m == BugMode.PhantomRecord) {
                // Copy the real record; exactly once per batch, inject a key that
                // never existed in v1 (I4) so the offender list stays deterministic.
                v2.migrateIn(key, label, owner_, expiry);
                if (i == start) {
                    bytes32 phantom = keccak256(abi.encodePacked(label, ":phantom"));
                    if (!v2.has(phantom)) {
                        v2.migrateIn(phantom, string.concat(label, ":phantom"), address(this), 0);
                    }
                }
            } else {
                // BugMode.None: behave exactly like the honest Migrator.
                v2.migrateIn(key, label, owner_, expiry);
            }
            emit Migrated(key); // forge-lint: disable-line(reentrancy-events)
        }
    }
}
