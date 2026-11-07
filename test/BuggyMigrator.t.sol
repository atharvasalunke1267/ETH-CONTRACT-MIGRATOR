// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV1} from "../src/RegistryV1.sol";
import {RegistryV2} from "../src/RegistryV2.sol";
import {BuggyMigrator} from "../src/BuggyMigrator.sol";
import {MigrationBase} from "./Common.t.sol";

/// @notice BuggyMigrator tests (T1.4): each bug mode breaks exactly its own invariant.
contract BuggyMigratorTest is MigrationBase {
    /// @dev Seeds the demo records, deploys a fresh v2 with the buggy migrator wired in,
    ///      and runs one full batch. Returns the v2 that was written.
    function _runBug(BuggyMigrator.BugMode mode) internal returns (RegistryV2 freshV2) {
        v1 = new RegistryV1(deployer);
        _register(v1, _demoNames());
        vm.startPrank(deployer);
        freshV2 = new RegistryV2(deployer);
        BuggyMigrator buggy = new BuggyMigrator(address(v1), address(freshV2), mode);
        freshV2.setMigrator(address(buggy));
        buggy.migrateBatch(0, 10);
        vm.stopPrank();
    }

    /// @dev DropLast: the final v1 record of the range never reaches v2 -> I3.
    function test_DropLastBreaks_I3_NoRecordLost() public {
        RegistryV2 freshV2 = _runBug(BuggyMigrator.BugMode.DropLast);

        assertEq(freshV2.recordCount(), 9, "exactly one record must go missing");

        (bytes32[] memory i3, uint256 i3Count) = _checkI3NoRecordLost(v1, freshV2, 10);
        assertEq(i3Count, 1, "I3 must fail");
        assertEq(i3[0], v1.keyAt(9), "the dropped one is the last key");
        assertEq(i3[0], keccak256(bytes("judy")));

        assertEq(_i1OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i2OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i4OffenderCount(v1, freshV2, 9), 0);
    }

    /// @dev ResetExpiry: copied expiry becomes 0 -> I2.
    function test_ResetExpiryBreaks_I2_ExpiryPreserved() public {
        RegistryV2 freshV2 = _runBug(BuggyMigrator.BugMode.ResetExpiry);

        (bytes32[] memory i2, uint256 i2Count) = _checkI2ExpiryPreserved(v1, freshV2, 10);
        assertEq(i2Count, 10, "every expiry must be wrong");
        for (uint256 i = 0; i < i2Count; ++i) {
            (, , uint64 v2Expiry, ) = freshV2.get(i2[i]);
            assertEq(v2Expiry, 0);
        }

        assertEq(_i1OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i3OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i4OffenderCount(v1, freshV2, 10), 0);
    }

    /// @dev SwapOwners: copied owner is replaced -> I1.
    function test_SwapOwnersBreaks_I1_OwnershipPreserved() public {
        RegistryV2 freshV2 = _runBug(BuggyMigrator.BugMode.SwapOwners);

        (bytes32[] memory i1, uint256 i1Count) = _checkI1OwnershipPreserved(v1, freshV2, 10);
        assertEq(i1Count, 10, "every owner must be wrong");
        address buggy = freshV2.migrator();
        for (uint256 i = 0; i < i1Count; ++i) {
            (, address v2Owner, , ) = freshV2.get(i1[i]);
            assertEq(v2Owner, buggy);
        }

        assertEq(_i2OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i3OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i4OffenderCount(v1, freshV2, 10), 0);
    }

    /// @dev PhantomRecord: one extra key exists in v2 only -> I4.
    function test_PhantomRecordBreaks_I4_NoPhantomRecords() public {
        RegistryV2 freshV2 = _runBug(BuggyMigrator.BugMode.PhantomRecord);

        assertEq(freshV2.recordCount(), 11, "one phantom record is injected");

        assertEq(_i4OffenderCount(v1, freshV2, 11), 1, "I4 must fail");
        bytes32 phantomKey = keccak256(bytes("alice:phantom"));
        assertFalse(v1.has(phantomKey), "phantom key never existed in v1");
        assertTrue(freshV2.has(phantomKey));

        assertEq(_i1OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i2OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i3OffenderCount(v1, freshV2, 10), 0);
    }

    /// @dev Mode None migrates exactly like the honest Migrator.
    function test_ModeNoneBehavesHonestly() public {
        RegistryV2 freshV2 = _runBug(BuggyMigrator.BugMode.None);

        assertEq(_i1OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i2OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i3OffenderCount(v1, freshV2, 10), 0);
        assertEq(_i4OffenderCount(v1, freshV2, 10), 0);
        assertEq(freshV2.recordCount(), 10);
    }

    function test_SetModeIsOneShotAndOwnerOnly() public {
        v1 = new RegistryV1(deployer);
        _register(v1, _demoNames());
        RegistryV2 freshV2 = new RegistryV2(deployer);
        BuggyMigrator buggy =
            new BuggyMigrator(address(v1), address(freshV2), BuggyMigrator.BugMode.None);

        vm.prank(makeAddr("stranger"));
        vm.expectRevert(BuggyMigrator.NotBuggyOwner.selector);
        buggy.setMode(BuggyMigrator.BugMode.SwapOwners);

        buggy.setMode(BuggyMigrator.BugMode.SwapOwners);
        vm.expectRevert(BuggyMigrator.ModeAlreadyFixed.selector);
        buggy.setMode(BuggyMigrator.BugMode.PhantomRecord);
    }
}
