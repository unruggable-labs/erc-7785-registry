// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IChainRegistry.sol";

interface IChainMetadataRegistry {
    /// @notice Called once by RootRegistry (via factory) to set immutable fields
    function initialize(address dao, ChainData calldata chainData) external;

    /// @notice DAO-multisig may alter auxiliary metadata (text records, coinType, etc.)
    function setText(string calldata key, string calldata value) external;

    function text(string calldata key) external view returns (string memory);

    /// @notice Returns the chain data fields needed to compute the chain ID (excludes chainName and coinType)
    function metadata()
        external
        view
        returns (
            uint256 settlementChainId,
            string memory version,
            address rollupContract,
            string memory chainNamespace,
            string memory chainReference
        );

    function coinType() external view returns (uint32);

    /// @notice Rotate the DAO multisig controlling this SubRegistry
    function updateDAOMultisig(address newMultisig) external;

    /// @notice Update the root owner (ENS DAO only)
    function updateRootOwner(address newRootOwner) external;

    /// @notice Allows the root owner (ENS DAO) to reclaim ownership
    function reclaimOwnership(address newOwner) external;
}
