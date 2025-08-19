// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ChainData {
    string chainName;
    uint256 settlementChainId;
    string version;
    address rollupContract;
    string chainNamespace;
    string chainReference;
    uint32 coinType;
}

interface IChainRegistry {
    /// @notice Register a new chain
    function register(ChainData calldata data, address dao) external;

    /// @notice Link an ENS node to a registered chain and set its ChainMetadataRegistry
    function linkNode(bytes32 node, bytes32 chainId, address chainMetadataRegistry) external;

    /// @notice Compute the canonical bytes32 ID from all ChainData fields
    function computeChainId(ChainData memory data) external pure returns (bytes32);

    /// @notice Compute CAIP-2 hash used for reverse lookups
    function computeCaip2Hash(string memory namespace, string memory chainReference) external pure returns (bytes32);

    /// @notice Lookup a chain's current versioned ID
    function resolve(bytes32 node) external view returns (bytes32);

    /// @notice Lookup the chain ID for a CAIP-2 identifier
    function resolveCAIP2(bytes32 caip2Hash) external view returns (bytes32);

    /// @notice Find the ChainMetadataRegistry address for a given chain-ID
    function resolveChainMetadataRegistry(bytes32 chainId) external view returns (address);

    /// @notice Get the chain name for a given chain ID
    function resolveChainName(bytes32 chainId) external view returns (string memory);

    /// @notice Get chain metadata for recomputing chain ID (excludes chainName and coinType)
    function metadata(bytes32 chainId)
        external
        view
        returns (
            uint256 settlementChainId,
            string memory version,
            address rollupContract,
            string memory chainNamespace,
            string memory chainReference
        );

    /// @notice Emit whenever a new chain is registered
    event ChainRegistered(bytes32 indexed chainId, string chainName, address dao);

    /// @notice Emit whenever an ENS node is linked to a chain
    event NodeLinked(bytes32 indexed node, bytes32 indexed chainId, address subRegistry);

    /// @notice Emit whenever someone bumps a chain's version
    event VersionBumped(bytes32 indexed chainId, string oldVersion, string newVersion);

    /// @notice Emit whenever chain data is updated (creates new chain ID)
    event ChainDataUpdated(bytes32 indexed oldChainId, bytes32 indexed newChainId, string chainName);

    /// @notice Only the ENS DAO (via on-chain governance) may bump a chain's version
    /// @dev This function only allows version string changes when no other attributes have changed
    function bumpVersion(bytes32 chainId, string calldata newVersion) external;

    /// @notice Update chain data with new attributes (creates new chain ID)
    /// @dev This function allows updating any field and generates a new chain ID
    function updateChainData(bytes32 chainId, ChainData calldata newData) external;
}
