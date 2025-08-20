// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library CAIP2 {

    /// @notice Compute CAIP-2 hash used for reverse lookups
    /// @param namespace CAIP-2 namespace (e.g., "eip155")
    /// @param chainReference CAIP-2 chain reference (e.g., "8453")
    /// @return bytes32 Hash of namespace:reference for CAIP-2 resolution
    function computeCaip2Hash(string memory namespace, string memory chainReference)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(namespace, ":", chainReference));
    }
}