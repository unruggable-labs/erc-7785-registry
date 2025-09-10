// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct ChainData {
    string chainName;
    uint256 settlementChainId;
    string version;
    address rollupContract;
    string chainNamespace;
    string chainReference;
    uint256 coinType;
}

interface IChainRegistry {
    
    /// @notice Emit whenever a new chain is registered
    event ChainRegistered(bytes32 indexed chainId, string chainName);

    error ChainNameEmpty();
    error ChainAlreadyRegistered();
    error ChainNameAlreadyRegistered();
    error CAIP2HashAlreadyRegistered();

    function register(ChainData calldata _chainData) external returns (bytes32);
    /// @notice DEMO-ONLY: Unrestricted register for the demo UI. Do NOT use in production.
    function demoRegister(ChainData calldata _chainData) external returns (bytes32);
}
