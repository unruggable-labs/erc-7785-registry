/**
 * @description Tests that ChainRegistry stores the computed ENSIP-11 coinType for Base (8453).
 * @usage       bun run tests/ChainRegistryCoinType.test.ts
 */

import { Foundry } from "@adraffy/blocksmith";
import { CHAIN_MAP } from "../deploy/constants";

const SEPOLIA_CHAIN_ID = 11155111;

const foundry = await Foundry.launch({
  fork: CHAIN_MAP.get(SEPOLIA_CHAIN_ID).rpc,
  procLog: true,
  infoLog: true,
});

// Deploy required libraries
const CAIP2 = await foundry.deploy({ file: "CAIP2", args: [] });
const ENSCoinType = await foundry.deploy({ file: "ENSCoinType", args: [] });
const ERC7785ChainId = await foundry.deploy({ file: "ERC7785ChainId", args: [] });

// Deploy ChainRegistry with libs
const chainRegistry = await foundry.deploy({
  file: "ChainRegistry",
  args: [],
  libs: { CAIP2, ENSCoinType, ERC7785ChainId },
});

// Base chain data (coinType can be 0; registry should compute ENSIP-11 for eip155)
const chainData = {
  chainName: "base",
  settlementChainId: 8453,
  version: "1",
  rollupContract: "0x49f53e41452C74589E85cA1677426Ba426459e85",
  chainNamespace: "eip155",
  chainReference: "8453",
  coinType: 0, // input may be zero; registry normalizes for eip155
};

const receipt = await foundry.confirm(chainRegistry.register(chainData));
const chainId = receipt.logs[0].args.chainId as string;

const [exists, stored] = await chainRegistry.chainDataFromId(chainId);

console.log("Exists:", exists);
console.log("Stored coinType:", stored.coinType.toString());

const expected = 2147492101n; // 0x80000000 | 8453
if (!exists || stored.coinType !== expected) {
  throw new Error(
    `Unexpected stored coinType: expected ${expected}, got ${stored.coinType} (exists=${exists})`
  );
}

await foundry.shutdown();

