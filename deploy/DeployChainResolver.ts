/**
 * @description This script deploys the ChainResolver contract, and verifies it on Etherscan. 
 * @usage       bun run deploy/DeployChainResolver.ts --chain=sepolia
 * @author      Thomas Clowes (clowes.eth)
 * @date        2025-08-22
 */

import {
    initSmith,
    promptContinueOrExit,
    deployContract,
    verifyContract,
    shutdownSmith,
    constructorCheck,
    loadDeployment,
} from './utils.js';


import { init } from './init';

// Initialize deployment
const { chainId, privateKey } = await init();

//Launch blocksmith
const { deployerWallet, smith, rl } = await initSmith(chainId, privateKey);

const shouldBegin = await promptContinueOrExit(rl, 'Start deployment? (y/n)');

if (shouldBegin) {

    // Load the ChainRegistry deployment - this must be deployed first
    const chainRegistryDeployment = await loadDeployment(chainId, 'ChainRegistry');

    // Deployment args/libs
    const contractArgs = [chainRegistryDeployment.target];
    const contractLibs = {};

    // The contract name
    const contractName = 'ChainResolver';

    // Prompt the user to deploy the contract
    const shouldDeployContract = await promptContinueOrExit(
        rl,
        `Deploy ${contractName}? (y/n)`
    );

    // If the user wants to deploy the contract, deploy it
    let deployedContract;
    let deployedContractAddress;

    if (shouldDeployContract) {

        const { contract, contractAddress, already } = await deployContract(
            smith,
            deployerWallet,
            contractName,
            contractArgs,
            contractLibs
        );

        deployedContract = contract;
        deployedContractAddress = contractAddress;

        if (already) constructorCheck(deployedContract.constructorArgs, contractArgs);
    }

    const shouldVerify = await promptContinueOrExit(
        rl,
        `Verify ${contractName}? (y/n)`
    );

    if (shouldVerify) {

        // Verify the contract
        await verifyContract(
            chainId,
            deployedContract,
            contractName,
            deployedContract.constructorArgs,
            contractLibs,
            smith
        );
    }
}

//Shutdown
await shutdownSmith(rl, smith);
