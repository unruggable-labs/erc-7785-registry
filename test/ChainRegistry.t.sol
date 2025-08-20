// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ChainRegistry} from "../src/ChainRegistry.sol";
import {ChainResolver} from "../src/ChainResolver.sol";

contract ChainRegistryTest is Test {
    ChainRegistry public chainRegistry;
    ChainResolver public chainResolver;

    address public owner = address(0x1);
    address public dao = address(0x2);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the implementation contract
        chainRegistry = new ChainRegistry();

        // Deploy the controller
        chainResolver = new ChainResolver(address(chainRegistry));


        vm.stopPrank();
    }

    function test_ChainRegistryDeployment() public view {
        assertEq(chainRegistry.owner(), owner);
    }

    function test_NodeGen() public view {
        string memory chainName = "base";

        //https://ethtools.com/ethereum-name-service/ens-namehash-labelhash-node-generator/base.cid.eth
        bytes32 expectedNode = 0x1e16f34c43f2046bde82808c3fc6f1ccda19f6846a4aa5e696099a6c1bc1c146;
        assertEq(chainResolver.computeNode(chainName), expectedNode);
    }
}
