// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RegistryV1} from "../src/RegistryV1.sol";

/// @title Seed
/// @notice Registers the ten demo records ("alice".."judy") in RegistryV1.
///         Requires V1_ADDRESS to be set (forge script reads .env automatically).
///         The caller must be RegistryV1's owner (the deployer).
contract Seed is Script {
    // Well-known Anvil account 0 fallback so local demos need no .env.
    uint256 private constant ANVIL_DEFAULT_PKEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() external {
        uint256 pkey = vm.envOr("PRIVATE_KEY", ANVIL_DEFAULT_PKEY);
        RegistryV1 v1 = RegistryV1(vm.envAddress("V1_ADDRESS"));

        vm.startBroadcast(pkey);
        _seed(v1);
        vm.stopBroadcast();

        console2.log("seeded v1 records:", v1.recordCount());
    }

    function _seed(RegistryV1 v1) internal {
        // Ten demo labels, each with its own owner and a distinct expiry.
        // This list must mirror cli/mguard/samples.py used by `mguard seed`.
        string[10] memory labels = ["alice", "bob", "carol", "dave", "erin", "frank", "grace", "heidi", "ivan", "judy"];
        for (uint256 i = 0; i < labels.length; ++i) {
            address owner_ = address(uint160(10001 + i)); // tidy, distinct demo owners
            uint64 expiry = uint64(1_800_000_000 + i); // roughly year 2027
            v1.register(labels[i], owner_, expiry);
        }
    }
}
