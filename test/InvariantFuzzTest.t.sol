// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV2} from "../src/RegistryV2.sol";
import {Migrator} from "../src/Migrator.sol";
import {BuggyMigrator} from "../src/BuggyMigrator.sol";
import {MigrationBase} from "./Common.t.sol";

/// @title InvariantFuzzTest
/// @notice For randomized record sets, the honest Migrator must keep I1..I5 true (T1.5),
///         and DropLast must always lose the last record.
contract InvariantFuzzTest is MigrationBase {
    uint256 internal constant MAX_RECORDS = 32;

    /// @notice Labels are unique by construction: "lbl-<salt>-<index>".
    function _randLabel(uint256 index, uint256 salt) internal pure returns (string memory) {
        return string.concat("lbl-", vm.toString(salt), "-", vm.toString(index));
    }

    /// @notice Deterministically derives a non-zero owner address and an expiry from a seed.
    function _randOwner(uint256 index, uint256 salt) internal pure returns (address) {
        bytes32 seed = keccak256(abi.encodePacked(index, "owner", salt));
        return address(uint160(uint256(seed)) | 1);
    }

    function _randExpiry(uint256 index, uint256 salt) internal pure returns (uint64) {
        bytes32 seed = keccak256(abi.encodePacked(index, "expiry", salt));
        return uint64(uint256(seed));
    }

    /// @notice Fuzz: seed 1..32 random records, migrate honestly; I1..I4 must hold
    ///         and a second identical batch must change nothing (I5).
    function testFuzz_HonestMigrationKeepsAllInvariants_Upto32Records(uint8 rawN, uint256 salt)
        public
    {
        uint256 n = bound(uint256(rawN), 1, MAX_RECORDS);

        _deployStack();
        vm.startPrank(deployer);
        for (uint256 i = 0; i < n; ++i) {
            v1.register(_randLabel(i, salt), _randOwner(i, salt), _randExpiry(i, salt));
        }
        honest.migrateBatch(0, n);
        vm.stopPrank();

        assertEq(_i1OffenderCount(v1, v2, n), 0);
        assertEq(_i2OffenderCount(v1, v2, n), 0);
        assertEq(_i3OffenderCount(v1, v2, n), 0);
        assertEq(_i4OffenderCount(v1, v2, n), 0);
        assertEq(v2.recordCount(), n);

        vm.prank(deployer);
        honest.migrateBatch(0, n);
        assertEq(v2.recordCount(), n);
        assertEq(_i1OffenderCount(v1, v2, n), 0);
        assertEq(_i2OffenderCount(v1, v2, n), 0);
    }

    /// @notice Fuzz: on any record set, DropLast skips exactly the final record.
    function testFuzz_BuggyDropLastAlwaysLosesTheLastRecord(uint8 rawN, uint256 salt) public {
        uint256 n = bound(uint256(rawN), 2, MAX_RECORDS);

        _deployStack();
        string[] memory labels = new string[](n);
        vm.startPrank(deployer);
        for (uint256 i = 0; i < n; ++i) {
            labels[i] = _randLabel(i, salt);
            v1.register(labels[i], _randOwner(i, salt), _randExpiry(i, salt));
        }
        RegistryV2 freshV2 = new RegistryV2(deployer);
        BuggyMigrator buggy = new BuggyMigrator(address(v1), address(freshV2), BuggyMigrator.BugMode.DropLast);
        freshV2.setMigrator(address(buggy));
        buggy.migrateBatch(0, n);
        vm.stopPrank();

        assertEq(freshV2.recordCount(), n - 1, "one record must go missing");
        (bytes32[] memory i3, uint256 i3Count) = _checkI3NoRecordLost(v1, freshV2, n);
        assertEq(i3Count, 1);
        assertEq(i3[0], keccak256(bytes(labels[n - 1])), "the dropped one is the last key");
    }
}
