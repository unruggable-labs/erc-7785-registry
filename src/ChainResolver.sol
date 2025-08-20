// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-v5/access/Ownable.sol";
import "@openzeppelin/contracts-v5/utils/introspection/IERC165.sol";
import "./interfaces/IChainRegistry.sol";
import "./ChainMetadataRegistry.sol";

// ENSIP-10 Interface
interface IENSIP10 {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

contract ChainResolver is Ownable, IERC165, IENSIP10 {

    error ChainNameEmpty();
    error UnsupportedFunction();

    // The ChainRegistry contract
    IChainRegistry public immutable chainRegistry;

    // Mapping from ENS node to chain ID
    mapping(bytes32 => bytes32) public nodeToChainId;

    // Events
    event NodeAssigned(bytes32 indexed node, string indexed label, bytes32 indexed chainId);

    // Function selectors
    bytes4 private constant TEXT_SELECTOR = bytes4(keccak256("text(bytes32,string)"));

    // Interface IDs
    bytes4 private constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 private constant RESOLVER_INTERFACE_ID = 0x3b3b57de; // text(bytes32,string)
    bytes4 private constant ENSIP10_INTERFACE_ID = 0x9061b923; // resolve(bytes,bytes)

    constructor(address _chainRegistry) Ownable(msg.sender) {
        chainRegistry = IChainRegistry(_chainRegistry);
    }

    /// @notice Check if the contract supports a specific interface
    /// @param interfaceId The interface identifier to check
    /// @return True if the interface is supported, false otherwise
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == ERC165_INTERFACE_ID || 
               interfaceId == RESOLVER_INTERFACE_ID ||
               interfaceId == ENSIP10_INTERFACE_ID;
    }

    /// @notice ENSIP-10 resolve function that parses calldata and handles text record resolution
    /// @param name The ENS name being resolved
    /// @param data The calldata to parse
    /// @return The result of the resolution
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory) {
        // Parse the function selector from calldata
        bytes4 selector = bytes4(data[:4]);
        
        if (selector == TEXT_SELECTOR) {
            // Parse the node and key from the calldata
            (bytes32 node, string memory key) = abi.decode(data[4:], (bytes32, string));
            
            // Check if the key is 'chain-id'
            if (keccak256(abi.encodePacked(key)) == keccak256(abi.encodePacked("chain-id"))) {
                // Return the chainId from the mapping
                bytes32 chainId = nodeToChainId[node];
                if (chainId != bytes32(0)) {
                    return abi.encode(chainId);
                }
                // Return empty bytes if no chainId found
                return "";
            }
            
            // For other text keys, return empty (not supported)
            // TODO: Metadata contracts? for chain operators - we could fall through
            return "";
        }
        
        // Unsupported function selector
        revert UnsupportedFunction();
    }

    /// @notice Assign a chain ID to an ENS node for a given label
    /// @param label The chain label (e.g., "base" for base.cid.eth)
    /// @param chainId The chain ID to assign to the node
    /// @dev Only callable by the owner
    function assign(string calldata label, bytes32 chainId) external onlyOwner {
        if (bytes(label).length == 0) {
            revert ChainNameEmpty();
        }

        // Calculate the ENS node for ${label}.cid.eth
        bytes32 node = computeNode(label);
        
        // Assign the chain ID to the node
        nodeToChainId[node] = chainId;
        
        emit NodeAssigned(node, label, chainId);
    }

    /// @notice Compute ENS namehash for a given chain name
    /// @param chainName Human-readable chain name (e.g., "base")
    /// @return bytes32 ENS namehash for  ${chainName}.cid.eth
    function computeNode(string memory chainName) internal pure returns (bytes32) {
        // Start with the TLD (.eth)
        bytes32 node = keccak256(abi.encodePacked(bytes32(0), keccak256(abi.encodePacked("eth")));
        
        // Add .cid subdomain
        node = keccak256(abi.encodePacked(node, keccak256(abi.encodePacked("cid")));
        
        // Add the chain name label
        node = keccak256(abi.encodePacked(node, keccak256(abi.encodePacked(chainName)));
        
        return node;
    }
}