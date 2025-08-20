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
        chainRegistry = new ChainRegistry(owner);

        // Deploy the controller
        chainResolver = new ChainResolver(address(chainRegistry));

        vm.stopPrank();
    }

    function test_ChainRegistryDeployment() public view {
        assertEq(chainRegistry.owner(), owner);
    }
}
