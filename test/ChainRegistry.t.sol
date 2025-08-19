// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ChainRegistry} from "../src/ChainRegistry.sol";
import {ChainMetadataRegistry} from "../src/ChainMetadataRegistry.sol";
import {CidRegistrarController} from "../src/CidRegistrarController.sol";

contract ChainRegistryTest is Test {
    ChainRegistry public chainRegistry;
    ChainMetadataRegistry public chainMetadataRegistryImplementation;
    CidRegistrarController public controller;

    address public owner = address(0x1);
    address public dao = address(0x2);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy the implementation contract
        chainMetadataRegistryImplementation = new ChainMetadataRegistry(owner);

        // Deploy the main registry
        chainRegistry = new ChainRegistry();

        // Deploy the controller
        controller = new CidRegistrarController(address(chainRegistry), address(chainMetadataRegistryImplementation));

        vm.stopPrank();
    }

    function test_ChainRegistryDeployment() public view {
        assertEq(chainRegistry.owner(), owner);
    }
}
