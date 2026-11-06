// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title RegistryV2 — the new registry, writable only by a trusted Migrator (I6).
/// @notice Same records as v1 plus a recorded migration timestamp.
contract RegistryV2 {
    struct _Record {
        string label;
        address owner;
        uint64 expiry;
        uint64 migratedAt; // new in v2: when this record was copied over
    }

    // ── Custom errors ────────────────────────────────────────────────
    error NotRegistryOwner();
    error NotMigrator();
    error MigratorAlreadySet();
    error MigratorZero();
    error LabelEmpty();
    error OwnerZero();
    error KeyAlreadyMigrated();
    error UnknownKey();
    error IndexError();

    // ── Events ───────────────────────────────────────────────────────
    /// @notice The one-time trusted migrator was set.
    event MigratorSet(address indexed migrator);
    /// @notice A record was copied in from v1.
    event MigratedIn(bytes32 indexed key, address indexed owner, uint64 expiry, uint64 migratedAt);

    address public owner;
    uint256 public recordCount;
    address public migrator; // set exactly once
    mapping(bytes32 key => _Record record) private _records;
    mapping(bytes32 key => bool exists) private _exists;
    bytes32[] private _keys;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotRegistryOwner();
        _;
    }

    modifier onlyMigrator() {
        if (msg.sender != migrator) revert NotMigrator(); // invariant I6
        _;
    }

    /// @param owner_ is the registry admin; it chooses the migrator once.
    constructor(address owner_) {
        if (owner_ == address(0)) revert OwnerZero();
        owner = owner_;
    }

    /// @notice Allow exactly one address to write migrated records. Callable once, by owner only.
    /// @param migrator_ is the migrator contract (honest or buggy) that gets write access.
    function setMigrator(address migrator_) external onlyOwner {
        if (migrator != address(0)) revert MigratorAlreadySet(); // cannot be undone
        if (migrator_ == address(0)) revert MigratorZero();

        migrator = migrator_;
        emit MigratorSet(migrator_);
    }

    /// @notice Write a migrated record directly. Only the trusted migrator may call this.
    /// @param key is keccak256(bytes(label)) — the same key scheme v1 uses.
    /// @param label is the copied label.
    /// @param owner_ is the copied owner.
    /// @param expiry is the copied expiry.
    function migrateIn(bytes32 key, string calldata label, address owner_, uint64 expiry)
        external
        onlyMigrator
    {
        if (owner_ == address(0)) revert OwnerZero();
        if (bytes(label).length == 0) revert LabelEmpty();
        if (_exists[key]) revert KeyAlreadyMigrated();

        _exists[key] = true;
        // forge-lint: disable-next-line(unsafe-typecast)
        // uint64 is the project-wide timestamp type; overflow is not a concern until 2106.
        _records[key] = _Record(label, owner_, expiry, uint64(block.timestamp));
        _keys.push(key);
        recordCount = _keys.length;

        // forge-lint: disable-next-line(unsafe-typecast)
        emit MigratedIn(key, owner_, expiry, uint64(block.timestamp));
    }

    /// @notice Key stored at enumeration index i.
    function keyAt(uint256 index) external view returns (bytes32 key) {
        if (index >= _keys.length) revert IndexError();
        key = _keys[index];
    }

    /// @notice True if the key exists in this registry.
    function has(bytes32 key) external view returns (bool) {
        return _exists[key];
    }

    /// @notice The full record stored under a key, including when it was migrated.
    function get(bytes32 key)
        external
        view
        returns (string memory label, address owner_, uint64 expiry, uint64 migratedAt)
    {
        if (!_exists[key]) revert UnknownKey();
        _Record storage r = _records[key];
        return (r.label, r.owner, r.expiry, r.migratedAt);
    }
}
