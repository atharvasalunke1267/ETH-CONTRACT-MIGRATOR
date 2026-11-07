// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RegistryV1} from "../src/RegistryV1.sol";
import {RegistryV2} from "../src/RegistryV2.sol";
import {Migrator} from "../src/Migrator.sol";
import {BuggyMigrator} from "../src/BuggyMigrator.sol";

/// @title Deploy
/// @notice Deploys the demo stack: RegistryV1, RegistryV2, honest Migrator,
///         BuggyMigrator (mode None). RegistryV2 is deliberately left UNWIRED —
///         whichever migrator `mguard migrate` runs will be wired in one-time
///         by the CLI, matching the demo flow in WORKFLOW.md.
///         Run with: forge script script/Deploy.s.sol --broadcast
contract Deploy is Script {
    uint256 private constant ANVIL_DEFAULT_PKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run()
        external
        returns (RegistryV1 v1, RegistryV2 v2, Migrator honest, BuggyMigrator buggy)
    {
        uint256 pkey = vm.envOr("PRIVATE_KEY", ANVIL_DEFAULT_PKEY);
        vm.startBroadcast(pkey);

        address deployer = vm.addr(pkey);

        address reusedV1 = vm.envOr("V1_ADDRESS", address(0));
        if (reusedV1 == address(0)) {
            v1 = new RegistryV1(deployer);
        } else {
            v1 = RegistryV1(reusedV1);
        }
        v2 = new RegistryV2(deployer);
        honest = new Migrator(address(v1), address(v2));
        buggy = new BuggyMigrator(address(v1), address(v2), BuggyMigrator.BugMode.None);

        vm.stopBroadcast();

        console2.log("REGISTRY_V1 =", address(v1));
        console2.log("REGISTRY_V2 =", address(v2));
        console2.log("MIGRATOR    =", address(honest));
        console2.log("BUGGY       =", address(buggy));
        console2.log("DEPLOYER    =", deployer);
    }
}
