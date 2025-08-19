// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-v5/access/Ownable.sol";
import "./IChainRegistry.sol";

contract ChainRegistry is IChainRegistry, Ownable {
    // Custom errors for better gas efficiency
    error ChainNotFound();
    error ChainNameEmpty();
    error VersionEmpty();
    error ChainMetadataRegistryZeroAddress();
    error VersionBumpWouldChangeChainId();
    error VersionsMustBeDifferent();
    error NewChainDataMustBeDifferent();
    error ChainAlreadyRegistered();

    mapping(bytes32 => ChainData) public chainData;
    mapping(bytes32 => bool) public chainExists;
    mapping(bytes32 => bytes32) public nodeToChainId;
    mapping(bytes32 => bytes32) public caip2HashToChainId;
    mapping(bytes32 => address) public chainMetadataRegistries;

    constructor() Ownable(msg.sender) {}

    /// @notice Register a new chain with the registry
    /// @param data Chain metadata including name, settlement chain ID, version, etc.
    /// @param dao Address of the DAO multisig that will control the chain
    /// @dev Validates chain name is not empty and generates unique chain ID
    /// @dev Sets up CAIP-2 reverse lookup for efficient chain resolution
    function register(ChainData calldata data, address dao) external override onlyOwner {
        // Validate that chainName is not empty
        if (bytes(data.chainName).length == 0) {
            revert ChainNameEmpty();
        }

        bytes32 chainId = computeChainId(data);

        if (chainExists[chainId]) {
            revert ChainAlreadyRegistered();
        }

        chainData[chainId] = data;
        chainExists[chainId] = true;

        // Compute CAIP-2 hash once and reuse
        bytes32 caip2Hash = computeCaip2Hash(data.chainNamespace, data.chainReference);
        caip2HashToChainId[caip2Hash] = chainId;

        emit ChainRegistered(chainId, data.chainName, dao);
    }

    /// @notice Link an ENS node to a registered chain and set its metadata registry
    /// @param node ENS node hash to link
    /// @param chainId Chain identifier to link the node to
    /// @param chainMetadataRegistry Address of the chain's metadata registry
    /// @dev Validates chain exists and metadata registry is not zero address
    function linkNode(bytes32 node, bytes32 chainId, address chainMetadataRegistry) external override onlyOwner {
        if (!chainExists[chainId]) {
            revert ChainNotFound();
        }

        // Validate that chainMetadataRegistry is not zero address
        if (chainMetadataRegistry == address(0)) {
            revert ChainMetadataRegistryZeroAddress();
        }

        nodeToChainId[node] = chainId;
        chainMetadataRegistries[chainId] = chainMetadataRegistry;

        emit NodeLinked(node, chainId, chainMetadataRegistry);
    }

    /// @notice Compute the canonical bytes32 ID from all ChainData fields
    /// @param data Chain metadata struct containing all chain information
    /// @return bytes32 Deterministic chain identifier
    /// @dev Uses keccak256 hash of all chain data fields for unique identification
    function computeChainId(ChainData memory data) public pure override returns (bytes32) {
        return keccak256(
            abi.encode(
                data.chainName,
                data.settlementChainId,
                data.version,
                data.rollupContract,
                data.chainNamespace,
                data.chainReference
            )
        );
    }

    /// @notice Compute CAIP-2 hash used for reverse lookups
    /// @param namespace CAIP-2 namespace (e.g., "eip155")
    /// @param chainReference CAIP-2 chain reference (e.g., "8453")
    /// @return bytes32 Hash of namespace:reference for CAIP-2 resolution
    function computeCaip2Hash(string memory namespace, string memory chainReference)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(namespace, ":", chainReference));
    }

    /// @notice Lookup a chain's current versioned ID by ENS node
    /// @param node ENS node hash to resolve
    /// @return bytes32 Associated chain identifier
    function resolve(bytes32 node) external view override returns (bytes32) {
        return nodeToChainId[node];
    }

    /// @notice Lookup the chain ID for a CAIP-2 identifier
    /// @param caip2Hash CAIP-2 hash to resolve
    /// @return bytes32 Associated chain identifier
    function resolveCAIP2(bytes32 caip2Hash) external view override returns (bytes32) {
        return caip2HashToChainId[caip2Hash];
    }

    /// @notice Find the ChainMetadataRegistry address for a given chain ID
    /// @param chainId Chain identifier to look up
    /// @return address ChainMetadataRegistry contract address
    function resolveChainMetadataRegistry(bytes32 chainId) external view override returns (address) {
        return chainMetadataRegistries[chainId];
    }

    /// @notice Get the chain name for a given chain ID
    /// @param chainId Chain identifier to look up
    /// @return string Chain name (e.g., "base", "optimism")
    /// @dev Returns empty string if chain ID is not found
    function resolveChainName(bytes32 chainId) external view returns (string memory) {
        if (!chainExists[chainId]) {
            return "";
        }
        return chainData[chainId].chainName;
    }

    /// @notice Get chain metadata for recomputing chain ID (excludes chainName and coinType)
    /// @param chainId Chain identifier to retrieve metadata for
    /// @return settlementChainId L1 settlement chain ID
    /// @return version Chain version string
    /// @return rollupContract L2 contract address on L1
    /// @return chainNamespace CAIP-2 namespace
    /// @return chainReference CAIP-2 chain reference
    /// @dev Returns only the fields needed to recompute the chain ID
    function metadata(bytes32 chainId)
        external
        view
        override
        returns (
            uint256 settlementChainId,
            string memory version,
            address rollupContract,
            string memory chainNamespace,
            string memory chainReference
        )
    {
        ChainData storage data = chainData[chainId];
        // Read all fields once to avoid multiple storage reads
        settlementChainId = data.settlementChainId;
        version = data.version;
        rollupContract = data.rollupContract;
        chainNamespace = data.chainNamespace;
        chainReference = data.chainReference;
    }

    /// @notice Update only the version string of an existing chain
    /// @param chainId Chain identifier to update
    /// @param newVersion New version string
    /// @dev Validates that only the version changes and chain ID remains the same
    /// @dev Emits VersionBumped event with old and new versions
    function bumpVersion(bytes32 chainId, string calldata newVersion) external override onlyOwner {
        if (!chainExists[chainId]) {
            revert ChainNotFound();
        }

        // Validate that new version is not empty
        if (bytes(newVersion).length == 0) {
            revert VersionEmpty();
        }

        ChainData storage data = chainData[chainId];

        // Validate that only the version is changing by checking if the new version
        // would create a different hash than the current chainId
        bytes32 newHash = keccak256(
            abi.encode(
                data.chainName,
                data.settlementChainId,
                newVersion,
                data.rollupContract,
                data.chainNamespace,
                data.chainReference
            )
        );

        if (newHash != chainId) {
            revert VersionBumpWouldChangeChainId();
        }

        // Validate that new version is different from old version
        if (keccak256(bytes(data.version)) == keccak256(bytes(newVersion))) {
            revert VersionsMustBeDifferent();
        }

        string memory oldVersion = data.version;
        data.version = newVersion;
        emit VersionBumped(chainId, oldVersion, newVersion);
    }

    /// @notice Update chain data with new attributes, creating a new chain ID
    /// @param oldChainId Current chain identifier
    /// @param newChainData New chain metadata
    /// @dev Generates new chain ID, updates mappings, and cleans up old data
    /// @dev Copies metadata registry from old chain ID to new one
    /// @dev Emits ChainDataUpdated event with old and new chain IDs
    function updateChainData(bytes32 oldChainId, ChainData calldata newChainData) external override onlyOwner {
        if (!chainExists[oldChainId]) {
            revert ChainNotFound();
        }

        // Validate that chainName is not empty
        if (bytes(newChainData.chainName).length == 0) {
            revert ChainNameEmpty();
        }

        // Read old data once and store in memory to avoid multiple storage reads
        ChainData memory oldData = chainData[oldChainId];

        // Validate that new data is different from old data by comparing hashes
        bytes32 oldHash = computeChainId(oldData);
        bytes32 newHash = computeChainId(newChainData);

        if (oldHash == newHash) {
            revert NewChainDataMustBeDifferent();
        }

        // Use the already computed newHash instead of computing it again
        bytes32 newChainId = newHash;

        if (chainExists[newChainId]) {
            revert ChainAlreadyRegistered();
        }

        // Compute old CAIP-2 hash using memory variables
        bytes32 oldCaip2Hash = computeCaip2Hash(oldData.chainNamespace, oldData.chainReference);

        // Store the new chain data with the new chain ID
        chainData[newChainId] = newChainData;
        chainExists[newChainId] = true;

        // Copy the ChainMetadataRegistry from the old chain ID
        address oldMetadataRegistry = chainMetadataRegistries[oldChainId];
        if (oldMetadataRegistry != address(0)) {
            chainMetadataRegistries[newChainId] = oldMetadataRegistry;
        }

        // Update CAIP-2 reverse lookup for the new chain
        bytes32 newCaip2Hash = computeCaip2Hash(newChainData.chainNamespace, newChainData.chainReference);
        caip2HashToChainId[newCaip2Hash] = newChainId;

        // Clean up the old chain ID
        delete chainData[oldChainId];
        delete chainExists[oldChainId];
        delete chainMetadataRegistries[oldChainId];

        // Clean up old CAIP-2 mapping if it exists
        if (caip2HashToChainId[oldCaip2Hash] == oldChainId) {
            delete caip2HashToChainId[oldCaip2Hash];
        }

        emit ChainDataUpdated(oldChainId, newChainId, newChainData.chainName);
    }
}
