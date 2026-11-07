// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title RegistryV1 — the old, deployed name registry being migrated to v2.
/// @notice Mapping of bytes32 keys to records, enumerable by index.
contract RegistryV1 {
    struct _Record {
        string label;
        address owner;
        uint64 expiry;
    }

    error NotRegistryOwner();
    error LabelEmpty();
    error OwnerZero();
    error KeyAlreadyRegistered();
    error UnknownKey();
    error IndexError();

    /// @notice A new key was registered.
    event Registered(bytes32 indexed key, string label, address indexed owner, uint64 expiry);

    address public owner;
    uint256 public recordCount;
    mapping(bytes32 key => _Record record) private _records;
    mapping(bytes32 key => bool exists) private _exists;
    bytes32[] private _keys;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotRegistryOwner();
        _;
    }

    /// @param owner_ is set as the contract admin who registers records (FR1).
    constructor(address owner_) {
        if (owner_ == address(0)) revert OwnerZero();
        owner = owner_;
    }

    function keys_length() external view returns (uint256) {
        return _keys.length;
    }

    /// @notice Register a label. Reverts if the key (keccak of the label) already exists.
    /// @param label is the human-readable name, such as "alice".
    /// @param owner_ is the account that owns the label.
    /// @param expiry is a Unix timestamp after which the label is considered expired.
    /// @return key is keccak256(bytes(label)), the on-chain storage key.
    function register(string calldata label, address owner_, uint64 expiry)
        external
        onlyOwner
        returns (bytes32 key)
    {
        if (owner_ == address(0)) revert OwnerZero();
        bytes memory labelBytes = bytes(label);
        if (labelBytes.length == 0) revert LabelEmpty();

        key = keccak256(labelBytes);
        if (_exists[key]) revert KeyAlreadyRegistered();

        _exists[key] = true;
        _records[key] = _Record(label, owner_, expiry);
        _keys.push(key);
        recordCount = _keys.length;

        emit Registered(key, label, owner_, expiry);
    }

    /// @notice Key stored at enumeration index i (ascending registration order).
    function keyAt(uint256 index) external view returns (bytes32 key) {
        if (index >= _keys.length) revert IndexError();
        key = _keys[index];
    }

    /// @notice True if the key exists in this registry.
    function has(bytes32 key) external view returns (bool) {
        return _exists[key];
    }

    /// @notice The full record stored under a key. Reverts if the key is unknown.
    function get(bytes32 key)
        external
        view
        returns (string memory label, address owner_, uint64 expiry)
    {
        _Record storage r = _records[key];
        if (!_exists[key]) revert UnknownKey();
        return (r.label, r.owner, r.expiry);
    }
}
