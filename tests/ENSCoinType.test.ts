/**
 * @description Validates ENSCoinType.evmCoinType() returns correct ENSIP-11 value for Base (8453).
 * @usage       bun run tests/ENSCoinType.test.ts
 */

import { Foundry } from "@adraffy/blocksmith";
import { Contract } from "ethers";
import { CHAIN_MAP } from "../deploy/constants";

const SEPOLIA_CHAIN_ID = 11155111;

const foundry = await Foundry.launch({
  fork: CHAIN_MAP.get(SEPOLIA_CHAIN_ID).rpc,
  procLog: true,
  infoLog: true,
});

// Deploy the ENSCoinType library
const ENSCoinType = await foundry.deploy({
  file: "ENSCoinType",
  args: [],
});

// Minimal ABI to call the library function
const abi = ["function evmCoinType(uint256) view returns (uint256)"];
const lib = new Contract(ENSCoinType.target, abi, foundry.provider);

const baseChainId = 8453n;
const expectedCoinType = 2147492101n; // 0x80000000 | 8453

const actualCoinType = await lib.evmCoinType(baseChainId);

console.log("ENSCoinType for Base (8453):", actualCoinType.toString());

if (actualCoinType !== expectedCoinType) {
  throw new Error(
    `Mismatch: expected ${expectedCoinType}, got ${actualCoinType}`
  );
}

await foundry.shutdown();

