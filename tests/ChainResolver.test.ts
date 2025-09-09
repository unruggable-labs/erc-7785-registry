/**
 * @description Deploys and tests the functioning of the ChainRegistry and ChainResolver contracts.
 * @usage       bun run tests/ChainResolver.test.ts
 * @author      Thomas Clowes (clowes.eth)
 * @date        2025-08-22
 */

import { Foundry } from "@adraffy/blocksmith";

import { Contract, namehash, toBeHex } from "ethers";

import { CHAIN_MAP } from "../deploy/constants";
import { solidityFollowSlot } from "./helpers";

// The second level name we are going to use to host chain-id resolution
const NAME_TO_TEST = "cid.eth";
const NODE = namehash(NAME_TO_TEST);
const SLOT = solidityFollowSlot(0, NODE) + 1n;

// ENS Registry address
const ENS = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";

const SEPOLIA_CHAIN_ID = 11155111;

// We propose standardizing on the 'chain-id' text record key for chain-id resolution
const CHAIN_ID_TEXT_RECORD_KEY = "chain-id";

const foundry = await Foundry.launch({
  fork: CHAIN_MAP.get(SEPOLIA_CHAIN_ID).rpc,
  procLog: true,
  infoLog: true,
});

// Deploy the libraries we need
const CAIP2 = await foundry.deploy({
  file: "CAIP2",
  args: [],
});

const ENSCoinType = await foundry.deploy({
  file: "ENSCoinType",
  args: [],
});

const ERC7785ChainId = await foundry.deploy({
  file: "ERC7785ChainId",
  args: [],
});

// Deploy the ChainRegistry
const chainRegistry = await foundry.deploy({
  file: "ChainRegistry",
  args: [],
  libs: { CAIP2, ENSCoinType, ERC7785ChainId },
});

// Our chain data for Base Sepolia subject to the in-process 7785 definition
const BASE_OPTIMISM_PORTAL_SEPOLIA =
  "0x49f53e41452C74589E85cA1677426Ba426459e85";
const BASE_CHAIN_NAME = "base";

const chainData = {
  chainName: BASE_CHAIN_NAME,
  settlementChainId: 8453,
  version: "1",
  rollupContract: BASE_OPTIMISM_PORTAL_SEPOLIA,
  chainNamespace: "eip155",
  chainReference: "8453",
  coinType: 8453,
};

// Register the chain data
const receipt = await foundry.confirm(chainRegistry.register(chainData));

// Get the 7785chain id from the receipt
const chainId = receipt.logs[0].args.chainId;

// Deploy the ChainResolver
const chainResolver = await foundry.deploy({
  file: "ChainResolver",
  args: [chainRegistry.target],
});

// Assign the chain id to the 'base' subname in the resolver
await foundry.confirm(chainResolver.assign(BASE_CHAIN_NAME, chainId));

// Hijack the ENS registry to point cid.eth's resolverto the ChainResolver
await foundry.provider.send("anvil_setStorageAt", [
  ENS,
  toBeHex(SLOT, 32),
  toBeHex(chainResolver.target, 32),
]);

const ens = new Contract(
  ENS,
  ["function resolver(bytes32 node) view returns (address)"],
  foundry.provider
);

console.log("Hijacked:", await ens.resolver(NODE));

// Helper function to resolve a chain-id from a name
async function resolve(name: string) {
  const resolver = await foundry.provider.getResolver(name);

  if (!resolver) throw new Error("bug");
  const [chainId] = await Promise.all([
    resolver.getText(CHAIN_ID_TEXT_RECORD_KEY),
  ]);
  console.log({
    name,
    chainId,
  });
}

// Do the resolution
await resolve(`${BASE_CHAIN_NAME}.${NAME_TO_TEST}`);

// We can now get the chain data from the chain registry using that chainId
// No need for any 'reverse lookup' as the 7785 chainId can be used to lookup all other chain data
const data = await chainRegistry.chainDataFromId(chainId);

console.log("Chain data:", data);

// Verify ENS coinType lookup works with both normalized (ENSIP-11) and raw chainId inputs
const [existsRaw] = await chainRegistry.chainDataFromEnsCoinType(8453n);
const normalizedCoinType = (1n << 31n) | 8453n; // ENSIP-11: MSB | chainId for non-mainnet
const [existsNormalized] = await chainRegistry.chainDataFromEnsCoinType(normalizedCoinType);
console.log("ENS coinType lookups:", { existsRaw, existsNormalized });

// Additional checks: uniqueness constraints with exact custom error decoding
async function expectRevertRegister(
  testName: string,
  payload: typeof chainData,
  expectedErrorName?: string,
) {
  // Simulate via eth_call to avoid estimateGas preflight and decode the custom error
  const calldata = chainRegistry.interface.encodeFunctionData("register", [payload]);
  try {
    const from = await foundry.wallets.admin.getAddress();
    await foundry.provider.call({ from, to: chainRegistry.target, data: calldata });
    console.error(`Expected revert: ${testName}`);
  } catch (err: any) {
    const raw = err?.data?.data ?? err?.data ?? err?.error?.data ?? err?.info?.error?.data;
    let decodedName = "unknown";
    try {
      const parsed = chainRegistry.interface.parseError(raw);
      decodedName = parsed?.name ?? decodedName;
    } catch {}
    if (expectedErrorName && decodedName !== expectedErrorName) {
      console.error(`Unexpected revert: got ${decodedName}, want ${expectedErrorName}`);
    } else {
      console.log(`Reverted as expected [${decodedName}]: ${testName}`);
    }
  }
}

// 1) Duplicate chainName should revert (different CAIP2 to isolate name check)
await expectRevertRegister(
  "duplicate chainName",
  {
    ...chainData,
  },
  "ChainNameAlreadyRegistered"
);

// 2) Duplicate CAIP2 pair should revert (different name to isolate CAIP2 check)
await expectRevertRegister(
  "duplicate CAIP2 pair",
  {
    ...chainData,
    chainName: "base-alt",
  },
  "CAIP2HashAlreadyRegistered"
);

// Prevent assigning the same label twice
async function expectRevertAssign(
  testName: string,
  label: string,
  id: string,
  expectedErrorName?: string
) {
  const calldata = chainResolver.interface.encodeFunctionData("assign", [label, id]);
  try {
    const from = await foundry.wallets.admin.getAddress();
    await foundry.provider.call({ from, to: chainResolver.target, data: calldata });
    console.error(`Expected revert: ${testName}`);
  } catch (err: any) {
    const raw = err?.data?.data ?? err?.data ?? err?.error?.data ?? err?.info?.error?.data;
    let decodedName = "unknown";
    try {
      const parsed = chainResolver.interface.parseError(raw);
      decodedName = parsed?.name ?? decodedName;
    } catch {}
    if (expectedErrorName && decodedName !== expectedErrorName) {
      console.error(`Unexpected revert: got ${decodedName}, want ${expectedErrorName}`);
    } else {
      console.log(`Reverted as expected [${decodedName}]: ${testName}`);
    }
  }
}

// 3) Duplicate label assignment should revert
await expectRevertAssign(
  "duplicate label same id",
  BASE_CHAIN_NAME,
  chainId,
  "LabelAlreadyAssigned"
);

// 4) Duplicate label with different id should also revert
await expectRevertAssign(
  "duplicate label different id",
  BASE_CHAIN_NAME,
  toBeHex(1n, 32),
  "LabelAlreadyAssigned"
);

await foundry.shutdown();
