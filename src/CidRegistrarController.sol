// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-v5/access/Ownable.sol";
import "./IChainRegistry.sol";
import "./ChainMetadataRegistry.sol";

contract CidRegistrarController is Ownable {
    // Custom errors for better gas efficiency
    error InsufficientFee();
    error InvalidDAOMultisig();
    error ChainNameEmpty();
    error RequestNotActive();
    error ObjectionWindowNotPassed();
    error NotController();

    // Access control roles
    address public controller;

    // Events for role management
    event ControllerUpdated(address indexed oldController, address indexed newController);

    IChainRegistry public immutable chainRegistry;
    ChainMetadataRegistry public immutable chainMetadataRegistryImplementation;

    uint256 public constant OBJECTION_WINDOW = 7 days;
    uint256 public constant REGISTRATION_FEE = 10 ether;

    struct RegistrationRequest {
        ChainData chainData;
        address daoMultisig;
        uint256 requestTime;
        bool isActive;
    }

    mapping(uint256 => RegistrationRequest) public requests;
    uint256 public requestCount;

    event RegistrationRequested(uint256 indexed requestId, string chainName, address daoMultisig);
    event RegistrationExecuted(uint256 indexed requestId, bytes32 indexed chainId, address subRegistry);
    event RegistrationRejected(uint256 indexed requestId);

    constructor(address _chainRegistry, address _chainMetadataRegistryImplementation) Ownable(msg.sender) {
        chainRegistry = IChainRegistry(_chainRegistry);
        chainMetadataRegistryImplementation = ChainMetadataRegistry(_chainMetadataRegistryImplementation);
        controller = msg.sender; // Initial controller is the deployer
    }

    // Modifiers for access control
    modifier onlyController() {
        if (msg.sender != controller && msg.sender != owner()) {
            revert NotController();
        }
        _;
    }

    /// @notice Submit a chain registration request with required fee
    /// @param chainData Chain metadata for registration
    /// @param daoMultisig Address of the DAO multisig that will control the chain
    /// @return requestId Unique identifier for the registration request
    /// @dev Validates fee amount, DAO multisig address, and chain name
    /// @dev Creates a new registration request with 7-day objection window
    function requestRegistration(ChainData calldata chainData, address daoMultisig)
        external
        payable
        returns (uint256)
    {
        if (msg.value < REGISTRATION_FEE) {
            revert InsufficientFee();
        }
        if (daoMultisig == address(0)) {
            revert InvalidDAOMultisig();
        }

        // Validate that chainName is not empty
        if (bytes(chainData.chainName).length == 0) {
            revert ChainNameEmpty();
        }

        uint256 requestId = requestCount++;
        requests[requestId] = RegistrationRequest({
            chainData: chainData,
            daoMultisig: daoMultisig,
            requestTime: block.timestamp,
            isActive: true
        });

        emit RegistrationRequested(requestId, chainData.chainName, daoMultisig);
        return requestId;
    }

    /// @notice Execute an approved chain registration after objection window
    /// @param requestId Identifier of the registration request to execute
    /// @dev Only callable by controller or owner after 7-day objection window
    /// @dev Deploys ChainMetadataRegistry, registers chain, and links ENS node
    /// @dev Clears request data after successful execution
    function executeRegistration(uint256 requestId) external onlyController {
        RegistrationRequest storage request = requests[requestId];
        if (!request.isActive) {
            revert RequestNotActive();
        }
        if (block.timestamp < request.requestTime + OBJECTION_WINDOW) {
            revert ObjectionWindowNotPassed();
        }

        // Compute chain ID once and reuse
        bytes32 chainId = chainRegistry.computeChainId(request.chainData);

        // Deploy ChainMetadataRegistry clone with ENS DAO as root owner
        ChainMetadataRegistry chainMetadataRegistry = new ChainMetadataRegistry(owner());

        // Initialize ChainMetadataRegistry
        chainMetadataRegistry.initialize(request.daoMultisig, request.chainData);

        // Register the chain
        chainRegistry.register(request.chainData, request.daoMultisig);

        // Link the ENS node and set ChainMetadataRegistry
        bytes32 node = computeNode(request.chainData.chainName);
        chainRegistry.linkNode(node, chainId, address(chainMetadataRegistry));

        // Mark request as executed and clear storage
        request.isActive = false;
        // Clear request data to save gas
        delete requests[requestId];

        emit RegistrationExecuted(requestId, chainId, address(chainMetadataRegistry));
    }

    /// @notice Reject a chain registration request and refund the fee
    /// @param requestId Identifier of the registration request to reject
    /// @dev Only callable by controller or owner
    /// @dev Refunds the registration fee to the original requester
    /// @dev Clears request data after rejection
    function rejectRegistration(uint256 requestId) external onlyController {
        RegistrationRequest storage request = requests[requestId];
        if (!request.isActive) {
            revert RequestNotActive();
        }

        // Store daoMultisig before clearing storage
        address daoMultisig = request.daoMultisig;

        // Clear request data to save gas
        request.isActive = false;
        delete requests[requestId];

        // Refund the fee
        payable(daoMultisig).transfer(REGISTRATION_FEE);

        emit RegistrationRejected(requestId);
    }

    /// @notice Compute ENS node hash for a given chain name
    /// @param chainName Human-readable chain name (e.g., "base")
    /// @return bytes32 ENS node hash for the chain name under cid.eth
    /// @dev Internal function that computes the deterministic ENS node
    function computeNode(string memory chainName) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked("", keccak256(abi.encodePacked("cid")))),
                keccak256(abi.encodePacked(chainName))
            )
        );
    }

    /// @notice Withdraw accumulated registration fees
    /// @dev Only callable by owner (ENS DAO) to withdraw collected fees
    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /// @notice Update the controller role for operational functions
    /// @param newController New controller address
    /// @dev Only callable by owner (ENS DAO) to rotate controller role
    /// @dev Emits ControllerUpdated event for transparency
    function updateController(address newController) external onlyOwner {
        if (newController == address(0)) {
            revert InvalidDAOMultisig(); // Reuse existing error
        }
        address oldController = controller;
        controller = newController;
        emit ControllerUpdated(oldController, newController);
    }

    receive() external payable {}
}
