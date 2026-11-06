// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV2} from "../src/RegistryV2.sol";
import {Migrator} from "../src/Migrator.sol";
import {MigrationBase} from "./Common.t.sol";

/// @notice Unit tests for RegistryV2 (T1.2): only the migrator can write (I6).
contract RegistryV2Test is MigrationBase {
    function setUp() public {
        _deployStack();
        _register(v1, _demoNames());
    }

    function test_MigratorCanWriteAfterSetMigrator() public {
        bytes32 key = v1.keyAt(0);
        (string memory label, address owner_, uint64 expiry) = v1.get(key);

        vm.prank(address(honest));
        v2.migrateIn(key, label, owner_, expiry);

        (string memory label2, address owner2, uint64 expiry2, uint64 migratedAt) = v2.get(key);
        assertEq(label2, label);
        assertEq(owner2, owner_);
        assertEq(expiry2, expiry);
        assertTrue(migratedAt > 0, "migration timestamp should be recorded");
    }

    function test_StrangerCannotWrite_I6() public {
        bytes32 key = v1.keyAt(0);
        (string memory label, address owner_, uint64 expiry) = v1.get(key);

        // Even the registry owner cannot write migrated records.
        vm.prank(deployer);
        vm.expectRevert(RegistryV2.NotMigrator.selector);
        v2.migrateIn(key, label, owner_, expiry);

        // Neither can a stranger.
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(RegistryV2.NotMigrator.selector);
        v2.migrateIn(key, label, owner_, expiry);
    }

    function test_SetMigratorWorksOnlyOnce() public {
        vm.prank(deployer);
        vm.expectRevert(RegistryV2.MigratorAlreadySet.selector);
        v2.setMigrator(makeAddr("second-migrator"));
    }

    function test_SetMigratorRejectsZeroAddress() public {
        RegistryV2 fresh = new RegistryV2(deployer);
        vm.prank(deployer);
        vm.expectRevert(RegistryV2.MigratorZero.selector);
        fresh.setMigrator(address(0));
    }

    function test_MigrateInRejectsDuplicateKey() public {
        bytes32 key = v1.keyAt(0);
        (string memory label, address owner_, uint64 expiry) = v1.get(key);
        vm.startPrank(address(honest));
        v2.migrateIn(key, label, owner_, expiry);
        vm.expectRevert(RegistryV2.KeyAlreadyMigrated.selector);
        v2.migrateIn(key, label, owner_, expiry);
        vm.stopPrank();
    }

    function test_GetUnknownKeyReverts() public {
        vm.expectRevert(RegistryV2.UnknownKey.selector);
        v2.get(bytes32(uint256(0x1234)));
    }
}
