// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Shared read/write interfaces both migrators use, kept in one place.
import {RegistryV1} from "./RegistryV1.sol";
import {RegistryV2} from "./RegistryV2.sol";

/// @dev The parts of RegistryV1 the migrators rely on.
interface IRegistryV1Like {
    function owner() external view returns (address);
    function recordCount() external view returns (uint256);
    function keyAt(uint256 index) external view returns (bytes32);
    function has(bytes32 key) external view returns (bool);
    function get(bytes32 key)
        external
        view
        returns (string memory label, address owner_, uint64 expiry);
}

/// @dev The parts of RegistryV2 the migrators rely on.
interface IRegistryV2Like {
    function owner() external view returns (address);
    function recordCount() external view returns (uint256);
    function keyAt(uint256 index) external view returns (bytes32);
    function has(bytes32 key) external view returns (bool);
    function migrateIn(bytes32 key, string calldata label, address owner_, uint64 expiry) external;
}
