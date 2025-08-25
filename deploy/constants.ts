/**
 * @description Misc constants, types etc
 * @author      Thomas Clowes (clowes.eth)
 * @date        2025-08-22
 */

import 'dotenv/config'

// Type for a specific chain
export type ChainInfo = {
    readonly chain: number;
    readonly name: string;
    readonly rpc: string;
};

export const CHAIN_MAP = new Map<number, ChainInfo>(
    [
        {
            chain: 1,
            name: 'mainnet',
            rpc: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
        },
        {
            chain: 11155111,
            name: 'sepolia',
            rpc: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
        },
    ]
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((x) => [x.chain, x])
);