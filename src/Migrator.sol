// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RegistryV1} from "./RegistryV1.sol";
import {RegistryV2} from "./RegistryV2.sol";
import {IRegistryV1Like, IRegistryV2Like} from "./Registries.sol";

/// @dev Shared interfaces now live in Registries.sol.

/// @title Migrator — the honest migration (FR2, FR3).
/// @notice Copies v1 records into v2 in bounded batches. Skips keys already migrated,
///         so running the same batch twice changes nothing (invariant I5, idempotency).
contract Migrator {
    /// @notice The batch size a caller may request at most, to keep loops bounded.
    uint256 public constant MAX_BATCH = 100;

    // ── Custom errors ────────────────────────────────────────────────
    error NotMigratorOwner();
    error BatchTooLarge();
    error RangeOutOfBounds();
    error CannotCopyV1Record(); // surfaces unexpected v1 read failures

    // ── Events ───────────────────────────────────────────────────────
    /// @notice A v1 key was copied into v2 in this batch.
    event Migrated(bytes32 indexed key);

    address public owner;
    IRegistryV1Like public immutable v1;
    IRegistryV2Like public immutable v2;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotMigratorOwner();
        _;
    }

    /// @param v1_ the old registry to read from.
    /// @param v2_ the new registry to write into (this contract must be its trusted migrator).
    constructor(address v1_, address v2_) {
        v1 = IRegistryV1Like(v1_);
        v2 = IRegistryV2Like(v2_);
        owner = msg.sender;
    }

    /// @notice Copy records [start, start+count) from v1 into v2.
    /// @param start is the first v1 enumeration index to copy.
    /// @param count is the number of records to attempt in this batch's bounded loop.
    function migrateBatch(uint256 start, uint256 count) external onlyOwner {
        if (count > MAX_BATCH) revert BatchTooLarge();
        if (start + count > v1.recordCount()) revert RangeOutOfBounds();

        uint256 end = start + count;
        // forge-lint: disable-next-line(calls-loop, require-revert-in-loop)
        // The loop is bounded by MAX_BATCH; cross-contract reads/writes are the step.
        for (uint256 i = start; i < end; ++i) {
            bytes32 key = v1.keyAt(i);
            // Idempotency (I5): never write a key that v2 already holds.
            if (v2.has(key)) continue;

            (string memory label, address owner_, uint64 expiry) = v1.get(key);
            if (owner_ == address(0)) revert CannotCopyV1Record();

            // Checks pass, effects happen in v2: copy exactly and emit.
            // forge-lint: disable-next-line(reentrancy-events)
            v2.migrateIn(key, label, owner_, expiry);
            emit Migrated(key);
        }
    }
}
