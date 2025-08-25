// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ChainData} from "../interfaces/IChainRegistry.sol";

library ERC7785ChainId {

    /// @notice Compute the canonical bytes32 ID from all ChainData fields
    /// @param data Chain metadata struct containing all chain information
    /// @return bytes32 Deterministic chain identifier
    /// @dev Uses keccak256 hash of all chain data fields for unique identification
    function computeChainId(ChainData memory data) public pure returns (bytes32) {
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
}