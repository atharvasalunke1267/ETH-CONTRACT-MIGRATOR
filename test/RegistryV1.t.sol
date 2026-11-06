// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV1} from "../src/RegistryV1.sol";
import {MigrationBase} from "./Common.t.sol";

/// @notice Unit tests for RegistryV1 (T1.1): register, get, enumeration, onlyOwner.
contract RegistryV1Test is MigrationBase {
    function test_RegisterStoresRecord() public {
        v1 = new RegistryV1(deployer);
        vm.prank(deployer);
        bytes32 key = v1.register("alice", address(0xA11CE), 1_900_000_000);

        assertEq(key, keccak256(bytes("alice")));
        (string memory label, address owner_, uint64 expiry) = v1.get(key);
        assertEq(label, "alice");
        assertEq(owner_, address(0xA11CE));
        assertEq(expiry, 1_900_000_000);
        assertEq(v1.recordCount(), 1);
    }

    function test_GetAndEnumerationWorkTogether() public {
        v1 = new RegistryV1(deployer);
        string[] memory labels = _demoLabels(3);
        _register(v1, labels);

        assertEq(v1.recordCount(), 3);
        for (uint256 i = 0; i < 3; ++i) {
            bytes32 key = v1.keyAt(i);
            assertEq(key, keccak256(bytes(labels[i]))); // registration order
            (string memory label, address owner_, uint64 expiry) = v1.get(key);
            assertEq(label, labels[i]);
            assertEq(owner_, makeAddr(labels[i]));
            assertEq(expiry, uint64(1_800_000_000 + i));
        }
    }

    function test_OnlyOwnerCanRegister() public {
        v1 = new RegistryV1(deployer);
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(RegistryV1.NotRegistryOwner.selector);
        v1.register("alice", address(0xA11CE), 1_900_000_000);
    }

    function test_DuplicateLabelReverts() public {
        v1 = new RegistryV1(deployer);
        vm.startPrank(deployer);
        v1.register("alice", address(0xA11CE), 1_900_000_000);
        vm.expectRevert(RegistryV1.KeyAlreadyRegistered.selector);
        v1.register("alice", address(0xB0B00), 1_900_000_001);
        vm.stopPrank();
    }

    function test_EmptyLabelReverts() public {
        v1 = new RegistryV1(deployer);
        vm.prank(deployer);
        vm.expectRevert(RegistryV1.LabelEmpty.selector);
        v1.register("", address(0xA11CE), 1_900_000_000);
    }

    function test_ZeroOwnerReverts() public {
        v1 = new RegistryV1(deployer);
        vm.prank(deployer);
        vm.expectRevert(RegistryV1.OwnerZero.selector);
        v1.register("alice", address(0), 1_900_000_000);
    }

    function test_GetUnknownKeyReverts() public {
        v1 = new RegistryV1(deployer);
        vm.expectRevert(RegistryV1.UnknownKey.selector);
        v1.get(bytes32(uint256(0x1234)));
    }
}
