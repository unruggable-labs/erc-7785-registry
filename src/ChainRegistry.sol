// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title  ERC-7785 Chain Registry
 * @notice Generates and stores ERC 7785 chain IDs based on use input
 * @dev    Provides getters for fetching chain data based on known historical 
 *         chain identification methodologies: CAIP-2, ENS coinType (ENSIP-11)
 * @author Thomas Clowes (clowes.eth)
 * @date   2025-08-22
 */

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IChainRegistry, ChainData} from "./interfaces/IChainRegistry.sol";
import {ERC7785ChainId} from "./libs/ERC7785ChainId.sol";
import {CAIP2} from "./libs/CAIP2.sol";
import {ENSCoinType} from "./libs/ENSCoinType.sol";

contract ChainRegistry is Ownable, IChainRegistry {

    // Mapping of chain ID to ChainData
    mapping(bytes32 => ChainData) public chainData;

    // Mapping of CAIP-2 hash to chain ID
    mapping(bytes32 => bytes32) public caip2HashToChainId;

    // Mapping of ENS coinType to chain ID
    mapping(uint256 => bytes32) public ensCoinTypeToChainId;


    constructor() Ownable(msg.sender) {}

    /// @notice Computes and registers the chain ID for a given ChainData struct
    /// @param _chainData the data used to discern the 7785 chain ID
    /// @dev Sets up CAIP-2 reverse lookup for efficient chain resolution
    function register(ChainData calldata _chainData) external onlyOwner returns (bytes32) {

        // Validate that chainName is not empty
        if (bytes(_chainData.chainName).length == 0) {
            revert ChainNameEmpty();
        }

        bytes32 chainId = ERC7785ChainId.computeChainId(_chainData);

        if (chainData[chainId].rollupContract != address(0)) {
            revert ChainAlreadyRegistered();
        }

        chainData[chainId] = _chainData;

        // Compute CAIP-2 hash once and map it to the chain ID
        bytes32 caip2Hash = CAIP2.computeCaip2Hash(_chainData.chainNamespace, _chainData.chainReference);
        caip2HashToChainId[caip2Hash] = chainId;

        uint32 ensCoinType = _chainData.coinType;

        // If the chain is an EVM chain, calculate the ENS coinType subject to ENSIP-11
        if (keccak256(abi.encodePacked(_chainData.chainNamespace)) == keccak256(abi.encodePacked("eip155"))) {
            ensCoinType = uint32(ENSCoinType.evmCoinType(_chainData.chainReference));
        }

        // Map the ENS coinType to the chain ID if not set
        if (ensCoinTypeToChainId[ensCoinType] == bytes32(0)) {
            ensCoinTypeToChainId[ensCoinType] = chainId;
        }

        emit ChainRegistered(chainId, _chainData.chainName);

        return chainId;
    }

    /// @notice Get the chain data for a given 7785 derived chain ID
    /// @param chainId Chain identifier to look up
    /// @return exists bool true if the chain exists
    /// @return ChainData the chain data
    function chainDataFromId(bytes32 chainId) public view returns (bool exists, ChainData memory) {
        if (chainData[chainId].rollupContract != address(0)) {
            exists = true;
        }
        return (exists, chainData[chainId]);
    }

    /// @notice Get the chain data for a given CAIP2 namespace and chain reference
    /// @param namespace CAIP2 namespace
    /// @param chainReference CAIP2 chain reference
    /// @return exists bool true if the chain exists
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
    /// @return exists bool true if the chain exists
    /// @return ChainData chainData the chain data
    function chainDataFromEnsCoinType(uint256 ensCoinType) external view returns (bool exists, ChainData memory) {
        return chainDataFromId(ensCoinTypeToChainId[ensCoinType]);
    }
}
