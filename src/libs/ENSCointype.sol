// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

library ENSCoinType {
    uint256 internal constant ENSIP11_MSB = 1 << 31; // 0x80000000

    /// @notice ENS coinType for a given EVM chainId per ENSIP-11.
    ///         Mainnet (chainId 1) returns 60 (SLIP-44 ETH).
    function evmCoinType(uint256 chainId) public pure returns (uint256) {
        if (chainId == 1) return 60; // canonical ETH cointype
        return ENSIP11_MSB | chainId;
    }

    /// @notice ENS coinType for the current chain.
    function evmCoinType() internal view returns (uint256) {
        return evmCoinType(block.chainid);
    }

    /// @notice Recover chainId from an ENSIP-11 coinType (or 60 -> 1).
    function chainIdFromCoinType(uint256 coinType) internal pure returns (uint256) {
        if (coinType == 60) return 1;
        // ENSIP-11 types have MSB set; mask it off to get the chainId.
        return coinType & (ENSIP11_MSB - 1); // 0x7fffffff
    }
}