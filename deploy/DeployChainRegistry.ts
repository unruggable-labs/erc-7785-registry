/**
 * @description This script deploys the ChainRegistry contract and verifies it on Etherscan.
 * @usage       bun run deploy/DeployChainRegistry.ts --chain=sepolia
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
} from "./utils.js";

import { init } from "./init.js";

// Initialize deployment
const { chainId, privateKey } = await init();

//Launch blocksmith
const { deployerWallet, smith, rl } = await initSmith(chainId, privateKey);

const shouldBegin = await promptContinueOrExit(rl, "Start deployment? (y/n)");

if (shouldBegin) {
  // These are the libraries that are required for the ChainRegistry contract deployment
  const extraLibsNames = ["CAIP2", "ENSCoinType", "ERC7785ChainId"];

  const shouldDeployLibs = await promptContinueOrExit(
    rl,
    `Deploy libraries? (${extraLibsNames}) (y/n)`
  );

  if (shouldDeployLibs) {
    console.log(`Deploying ${extraLibsNames}?`);

    let allLibs = {};

    for (let libName of extraLibsNames) {
      console.log(`Deploying ${libName}?`);

      const libArgs = [];
      const libLibs = {};

      const { contract, contractAddress } = await deployContract(
        smith,
        deployerWallet,
        libName,
        libArgs,
        libLibs
      );

      const shouldVerifyLib = await promptContinueOrExit(
        rl,
        `Verify ${libName}? (y/n)`
      );

      if (shouldVerifyLib) {
        await verifyContract(
          chainId,
          contract,
          libName,
          libArgs,
          libLibs,
          smith
        );
      }

      allLibs[libName] = {
        contract: contract,
        contractAddress: await contract.getAddress(),
        already: true,
      };
    }

    const contractName = "ChainRegistry";

    const shouldDeployContract = await promptContinueOrExit(
      rl,
      `Deploy ${contractName}? (y/n)`
    );

    let deployedContract;
    let deployedContractAddress;
    if (shouldDeployContract) {
      const contractArgs = [];
      //const contractLibs = {CAIP2};

      const { contract, contractAddress, already } = await deployContract(
        smith,
        deployerWallet,
        contractName,
        contractArgs,
        allLibs
      );

      deployedContract = contract;
      deployedContractAddress = contractAddress;

      if (already)
        constructorCheck(deployedContract.constructorArgs, contractArgs);

      const shouldVerify = await promptContinueOrExit(
        rl,
        `Verify ${contractName}? (y/n)`
      );

      if (shouldVerify) {
        await verifyContract(
          chainId,
          deployedContract,
          contractName,
          deployedContract.constructorArgs,
          allLibs,
          smith
        );
      }
    }
  }
}

//Shutdown
await shutdownSmith(rl, smith);
