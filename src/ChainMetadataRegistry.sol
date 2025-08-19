// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-v5/access/Ownable.sol";
import "./IChainMetadataRegistry.sol";

contract ChainMetadataRegistry is IChainMetadataRegistry, Ownable {
    // Custom errors for better gas efficiency
    error AlreadyInitialized();
    error MetadataCannotBeChanged();
    error InvalidMultisigAddress();
    error InvalidRootOwnerAddress();
    error CallerNotRootOwner();
    error NotDAO();

    // Fields set once by RootRegistry in initialize
    address public rootOwner;
    address public dao;
    ChainData public chainData;

    // Mutable text records
    mapping(string => string) private textRecords;

    constructor(address _rootOwner) Ownable(msg.sender) {
        rootOwner = _rootOwner;
    }

    // Modifiers for access control
    modifier onlyDAO() {
        if (msg.sender != dao) {
            revert NotDAO();
        }
        _;
    }

    modifier onlyRootOwner() {
        if (msg.sender != rootOwner) {
            revert CallerNotRootOwner();
        }
        _;
    }

    /// @notice Initialize the metadata registry with chain-specific data
    /// @param _dao Address of the DAO multisig that will control this registry
    /// @param _chainData Chain metadata to store
    /// @dev Only callable once by the controller during deployment
    /// @dev Transfers ownership to the DAO after initialization
    function initialize(address _dao, ChainData calldata _chainData) external override onlyOwner {
        if (dao != address(0)) {
            revert AlreadyInitialized();
        }

        dao = _dao;
        chainData = _chainData;

        // Transfer ownership directly to DAO
        _transferOwnership(_dao);
    }

    /// @notice Set a text record for the chain
    /// @param key Text record key (e.g., "website", "description")
    /// @param value Text record value
    /// @dev Only callable by the DAO multisig
    /// @dev Prevents modification of the "metadata" key for security
    function setText(string calldata key, string calldata value) external override onlyDAO {
        if (keccak256(bytes(key)) == keccak256(bytes("metadata"))) {
            revert MetadataCannotBeChanged();
        }
        textRecords[key] = value;
    }

    /// @notice Retrieve a text record by key
    /// @param key Text record key to look up
    /// @return value Associated text record value
    function text(string calldata key) external view override returns (string memory) {
        return textRecords[key];
    }

    /// @notice Get chain metadata fields needed to recompute chain ID
    /// @return settlementChainId L1 settlement chain ID
    /// @return version Chain version string
    /// @return rollupContract L2 contract address on L1
    /// @return chainNamespace CAIP-2 namespace
    /// @return chainReference CAIP-2 chain reference
    /// @dev Returns only the fields needed for chain ID computation
    /// @dev Excludes chainName and coinType as specified in ERC-7785
    function metadata()
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
        return (
            chainData.settlementChainId,
            chainData.version,
            chainData.rollupContract,
            chainData.chainNamespace,
            chainData.chainReference
        );
    }

    /// @notice Get the BIP-44 coin type for the chain
    /// @return uint32 Coin type value for address derivation
    /// @dev Required for proper address formatting and cross-chain compatibility
    function coinType() external view override returns (uint32) {
        return chainData.coinType;
    }

    /// @notice Rotate the DAO multisig controlling this registry
    /// @param newMultisig New DAO multisig address
    /// @dev Only callable by the current DAO multisig
    /// @dev Transfers ownership to the new multisig
    function updateDAOMultisig(address newMultisig) external override onlyDAO {
        if (newMultisig == address(0)) {
            revert InvalidMultisigAddress();
        }
        _transferOwnership(newMultisig);
    }

    /// @notice Update the root owner (ENS DAO) address
    /// @param newRootOwner New root owner address
    /// @dev Only callable by the current root owner
    /// @dev Allows ENS DAO to rotate its governance multisig
    function updateRootOwner(address newRootOwner) external onlyRootOwner {
        if (newRootOwner == address(0)) {
            revert InvalidRootOwnerAddress();
        }
        rootOwner = newRootOwner;
    }

    /// @notice Allow the root owner (ENS DAO) to reclaim ownership
    /// @param newOwner New owner address to transfer to
    /// @dev Only callable by the root owner
    /// @dev Provides ultimate control mechanism for ENS DAO
    function reclaimOwnership(address newOwner) external onlyRootOwner {
        _transferOwnership(newOwner);
    }
}
