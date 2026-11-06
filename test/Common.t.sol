// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RegistryV1} from "../src/RegistryV1.sol";
import {RegistryV2} from "../src/RegistryV2.sol";
import {Migrator} from "../src/Migrator.sol";
import {BuggyMigrator} from "../src/BuggyMigrator.sol";

/// @title MigrationBase
/// @notice Shared fixture: deploys v1+v2+wires the migrator, seeds sample records,
///         and mirrors the four off-chain invariant checks in Solidity.
contract MigrationBase is Test {
    RegistryV1 internal v1;
    RegistryV2 internal v2;
    Migrator internal honest;

    address internal deployer = makeAddr("deployer"); // owns v1, v2 and both migrators

    function _deployStack() internal returns (RegistryV1, RegistryV2, Migrator) {
        vm.startPrank(deployer);
        v1 = new RegistryV1(deployer);
        v2 = new RegistryV2(deployer);
        honest = new Migrator(address(v1), address(v2));
        v2.setMigrator(address(honest));
        vm.stopPrank();
        return (v1, v2, honest);
    }

    /// @notice Registers `labels` in v1; the deployer is v1's owner.
    function _register(RegistryV1 registry, string[] memory labels) internal {
        vm.startPrank(deployer);
        for (uint256 i = 0; i < labels.length; ++i) {
            registry.register(labels[i], makeAddr(labels[i]), uint64(1_800_000_000 + i));
        }
        vm.stopPrank();
    }

    /// @notice Builds `n` unique labels ("0", "1", ... as demo short names).
    function _demoLabels(uint256 n) internal pure returns (string[] memory labels) {
        labels = new string[](n);
        for (uint256 i = 0; i < n; ++i) {
            labels[i] = vm.toString(i);
        }
    }

    /// @notice The ten demo names the CLI also seeds.
    function _demoNames() internal pure returns (string[] memory names) {
        names = new string[](10);
        names[0] = "alice";
        names[1] = "bob";
        names[2] = "carol";
        names[3] = "dave";
        names[4] = "erin";
        names[5] = "frank";
        names[6] = "grace";
        names[7] = "heidi";
        names[8] = "ivan";
        names[9] = "judy";
    }

    // ── Solidity-side invariant checks (the same rules mguard runs off-chain) ──

    /// @notice I1: every v1 record has the same owner in v2.
    function _checkI1OwnershipPreserved(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (bytes32[] memory offenders, uint256 offendersCount)
    {
        offenders = new bytes32[](countV1);
        offendersCount = 0;
        for (uint256 i = 0; i < countV1; ++i) {
            bytes32 key = a.keyAt(i);
            if (!b.has(key)) continue; // I3 covers missing keys
            (, address v1Owner, ) = a.get(key);
            (, address v2Owner, , ) = b.get(key);
            if (v2Owner != v1Owner) offenders[offendersCount++] = key;
        }
    }

    /// @notice I2: every v1 expiry is preserved in v2.
    function _checkI2ExpiryPreserved(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (bytes32[] memory offenders, uint256 offendersCount)
    {
        offenders = new bytes32[](countV1);
        offendersCount = 0;
        for (uint256 i = 0; i < countV1; ++i) {
            bytes32 key = a.keyAt(i);
            if (!b.has(key)) continue;
            (, , uint64 v1Expiry) = a.get(key);
            (, , uint64 v2Expiry, ) = b.get(key);
            if (v2Expiry != v1Expiry) offenders[offendersCount++] = key;
        }
    }

    /// @notice I3: every v1 key exists in v2.
    function _checkI3NoRecordLost(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (bytes32[] memory offenders, uint256 offendersCount)
    {
        offenders = new bytes32[](countV1);
        offendersCount = 0;
        for (uint256 i = 0; i < countV1; ++i) {
            bytes32 key = a.keyAt(i);
            if (!b.has(key)) offenders[offendersCount++] = key;
        }
    }

    /// @notice I4: v2 holds no key that is absent from v1.
    function _checkI4NoPhantomRecords(RegistryV1 a, RegistryV2 b, uint256 countV2)
        internal
        view
        returns (bytes32[] memory offenders, uint256 offendersCount)
    {
        offenders = new bytes32[](countV2);
        offendersCount = 0;
        for (uint256 i = 0; i < countV2; ++i) {
            bytes32 key = b.keyAt(i);
            if (!a.has(key)) offenders[offendersCount++] = key;
        }
    }

    // ── Count-only wrappers, for tests that only need pass/fail numbers ──

    function _i1OffenderCount(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < countV1; ++i) {
            bytes32 key = a.keyAt(i);
            if (!b.has(key)) continue;
            (, address v1Owner, ) = a.get(key);
            (, address v2Owner, , ) = b.get(key);
            if (v2Owner != v1Owner) ++count;
        }
    }

    function _i2OffenderCount(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < countV1; ++i) {
            bytes32 key = a.keyAt(i);
            if (!b.has(key)) continue;
            (, , uint64 v1Expiry) = a.get(key);
            (, , uint64 v2Expiry, ) = b.get(key);
            if (v2Expiry != v1Expiry) ++count;
        }
    }

    function _i3OffenderCount(RegistryV1 a, RegistryV2 b, uint256 countV1)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < countV1; ++i) {
            if (!b.has(a.keyAt(i))) ++count;
        }
    }

    function _i4OffenderCount(RegistryV1 a, RegistryV2 b, uint256 countV2)
        internal
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < countV2; ++i) {
            if (!a.has(b.keyAt(i))) ++count;
        }
    }
}
