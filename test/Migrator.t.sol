// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {Migrator} from "../src/Migrator.sol";
import {MigrationBase} from "./Common.t.sol";

/// @notice Honest Migrator tests (T1.3): I1..I5 hold on the 10-sample demo data.
contract MigratorTest is MigrationBase {
    function setUp() public {
        _deployStack();
        _register(v1, _demoNames());
        vm.prank(deployer);
        honest.migrateBatch(0, 10);
    }

    function test_OwnershipPreserved_I1() public view {
        assertEq(_i1OffenderCount(v1, v2, 10), 0);
        assertEq(v2.recordCount(), 10);
    }

    function test_ExpiryPreserved_I2() public view {
        assertEq(_i2OffenderCount(v1, v2, 10), 0);
    }

    function test_NoRecordLost_I3() public view {
        assertEq(_i3OffenderCount(v1, v2, 10), 0);
    }

    function test_NoPhantomRecords_I4() public view {
        assertEq(_i4OffenderCount(v1, v2, 10), 0);
    }

    function test_MigrationIsIdempotent_I5() public {
        // Second run: everything already migrated, so nothing may change.
        vm.recordLogs();
        vm.prank(deployer);
        honest.migrateBatch(0, 10);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes32 migratedSig = keccak256("Migrated(bytes32)");
        uint256 migratedEvents;
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].emitter == address(honest) && logs[i].topics[0] == migratedSig) {
                ++migratedEvents;
            }
        }
        assertEq(migratedEvents, 0, "second run must emit no Migrated events");
        assertEq(v2.recordCount(), v1.recordCount()); // no new records either
    }

    function test_OnlyOwnerCanMigrate() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(Migrator.NotMigratorOwner.selector);
        honest.migrateBatch(0, 1);
    }

    function test_BatchTooLargeReverts() public {
        vm.prank(deployer);
        vm.expectRevert(Migrator.BatchTooLarge.selector);
        honest.migrateBatch(0, 101);
    }

    function test_RangeOutOfBoundsReverts() public {
        vm.prank(deployer);
        vm.expectRevert(Migrator.RangeOutOfBounds.selector);
        honest.migrateBatch(0, 11); // v1 only holds 10 records
    }
}
