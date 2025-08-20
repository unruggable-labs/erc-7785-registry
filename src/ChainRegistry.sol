// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-v5/access/Ownable.sol";
import "./interfaces/IChainRegistry.sol";

contract ChainRegistry is IChainRegistry, Ownable {

    error ChainNameEmpty();
    error ChainAlreadyRegistered();

    // Mapping of chain ID to ChainData
    mapping(bytes32 => ChainData) public chainData;

    // Mapping of CAIP-2 hash to chain ID
    mapping(bytes32 => bytes32) public caip2HashToChainId;

    // Mapping of ENS coinType to chain ID
    mapping(uint256 => bytes32) public ensCoinTypeToChainId;


    constructor() Ownable(msg.sender) {}

    /// @notice Computes and registers the chain ID for a given ChainData struct
    /// @param chainData the data used to discern the 7785 chain ID
    /// @dev Sets up CAIP-2 reverse lookup for efficient chain resolution
    function register(ChainData calldata _chainData) external override onlyOwner {

        // Validate that chainName is not empty
        if (bytes(_chainData.chainName).length == 0) {
            revert ChainNameEmpty();
        }

        bytes32 chainId = computeChainId(_chainData);

        if (chainExists[chainId]) {
            revert ChainAlreadyRegistered();
        }

        chainData[chainId] = _chainData;

        // Compute CAIP-2 hash once and map it to the chain ID
        bytes32 caip2Hash = CAIP2.computeCaip2Hash(_chainData.chainNamespace, _chainData.chainReference);
        caip2HashToChainId[caip2Hash] = chainId;

        uint32 ensCoinType = _chainData.coinType;

        // If the chain is an EVM chain, calculate the ENS coinType subject to ENSIP-11
        if (_chainData.chainNamespace == "eip155") {
            ensCoinType = ENSCoinType.evmCoinType(_chainData.chainReference);
        }

        // Map the ENS coinType to the chain ID if not set
        if (ensCoinTypeToChainId[ensCoinType] == bytes32(0)) {
            ensCoinTypeToChainId[ensCoinType] = chainId;
        }

        emit ChainRegistered(chainId, _chainData.chainName);
    }

    /// @notice Get the chain data for a given CAIP2 namespace and chain reference
    /// @param namespace CAIP2 namespace
    /// @param chainReference CAIP2 chain reference
    /// @return bool exists true if the chain exists
    /// @return ChainData chainData the chain data
    function chainDataFromCaip2(string memory namespace, string memory chainReference)
        public
        view
        returns (bool exists, ChainData memory)
    {
        bytes32 caip2Hash = CAIP2.computeCaip2Hash(namespace, chainReference);
        return chainDataFromId(caip2HashToChainId[caip2Hash]);
    }

    /// @notice Get the chain data for a given ENS coinType
    /// @param ensCoinType ENS coinType to look up
    /// @return bool exists true if the chain exists
    /// @return ChainData chainData the chain data
    function chainDataFromEnsCoinType(uint256 ensCoinType) external view returns (bool exists, ChainData memory) {
        return chainDataFromId(ensCoinTypeToChainId(ensCoinType));
    }

    /// @notice Get the chain data for a given 7785 derived chain ID
    /// @param chainId Chain identifier to look up
    /// @return bool exists true if the chain exists
    /// @return ChainData chainData the chain data
    function chainDataFromId(bytes32 chainId) external view returns (bool exists, ChainData memory) {
        if (chainData[chainId].name != "") {
            exists = true;
        }
        return (exists, chainData[chainId]);
    }
}
