## Run It

**Setup**

Create `.env` (see `.env.example`)

```
forge install
bun i
```

**Test**
```
bun run tests/ChainResolver.test.ts
```

**Deploy**
```
bun run deploy/DeployChainRegistry.ts --chain=sepolia
bun run deploy/DeployChainResolver.ts --chain=sepolia
```

## Architecture

This architectural approach gives consideration to historic chain identification formats (CAIP-2, SLIP-44, ENS Cointype (ENSIP-11)) as well as current standardization efforts (ERC-7785, ERC-7930).

It focuses on simplicity.

There are two contracts:

### ChainRegistry

This contract allows for the registration and tracking of 7785 chainIds based on inputted data.

### ChainResolver

This contract is a resolver to be set on the second level ENS name associated with chain identity resolution. We propose `cid.eth`.

This current minimal implementation resolves the `chain-id` text record for a given subname e.g. `base.cid.eth`. This chainId can then be used to query the `chainDataFromId` function on the `ChainRegistry`.

## Thoughts

Based on the development of this PoC we feel that 7785 is uneccesarily complex and contains extraneous data. Proposal incoming..