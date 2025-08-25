/**
 * @description Misc helpers
 * @author      Thomas Clowes (clowes.eth)
 * @date        2025-08-22
 */

import { BigNumberish, BytesLike, concat, keccak256 } from "ethers";

export function toPaddedHex(x: BigNumberish | boolean, width = 32) {
    const i = x === '0x' ? 0n : BigInt.asUintN(width << 3, BigInt(x));
    return '0x' + i.toString(16).padStart(width << 1, '0');
  }

// Builds a slot ID for a mapping
export function solidityFollowSlot(slot: BigNumberish, key: BytesLike) {
    // https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html#mappings-and-dynamic-arrays
    return BigInt(keccak256(concat([key, toPaddedHex(slot)])));
}

export function pow256(base: bigint, exp: bigint) {
    let res = 1n;
    while (exp) {
        if (exp & 1n) res = BigInt.asUintN(256, res * base);
        exp >>= 1n;
        base = BigInt.asUintN(256, base * base);
    }
    return res;
}