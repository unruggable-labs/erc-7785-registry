# Chain Registry Architecture

## Overview

The Chain Registry is a decentralized system for registering and resolving blockchain chain identifiers through ENS (Ethereum Name Service). It enables human-readable chain names (e.g., `base.cid.eth`) to resolve to standardized chain identifiers and metadata.

## Core Components

### 1. ChainRegistry Contract

**Purpose**: Central registry for chain data and ENS node resolution

**Key Functions**:

- `register()`: Stores chain metadata and generates unique chain ID
- `linkNode()`: Links ENS nodes (derived from human-friendly labels) to registered chains
- `resolve()`: Resolves ENS nodes to chain IDs
- `resolveCAIP2()`: Resolves CAIP-2 hashes to chain IDs
- `resolveChainName()`: Resolves chain IDs to human-readable chain names
- `resolveChainMetadataRegistry()`: Finds metadata registry for a given chain ID
- `bumpVersion()`: Updates chain versions (version-only changes)
- `updateChainData()`: Updates chain data with new attributes (creates new chain ID)

**Data Structure**:

```solidity
struct ChainData {
  string chainName; // Human-readable name (e.g., "base")
  uint256 settlementChainId; // L1 settlement chain ID
  string version; // Chain version string
  address rollupContract; // L2 contract address on L1
  string chainNamespace; // CAIP-2 namespace (e.g., "eip155")
  string chainReference; // CAIP-2 reference (e.g., "8453")
  uint32 coinType; // BIP-44 coin type
}
```

### 2. ChainMetadataRegistry Contract

**Purpose**: Per-chain metadata management and text records

**Key Functions**:

- `initialize()`: Sets up chain-specific data (one-time, controller-only)
- `setText()`: DAO-managed text records (e.g., website, description)
- `text()`: Retrieves text records by key
- `metadata()`: Returns chain data for ID recomputation
- `coinType()`: Returns the BIP-44 coin type for the chain
- `updateDAOMultisig()`: Rotates DAO control (DAO-only)
- `updateRootOwner()`: Updates root owner (ENS DAO only)
- `reclaimOwnership()`: Allows ENS DAO to reclaim ownership

**Deployment Pattern**: Cloned for each registered chain

### 3. CidRegistrarController Contract

**Purpose**: Manages the chain registration process with governance controls

**Key Functions**:

- `requestRegistration()`: Creates registration request with fee (public)
- `executeRegistration()`: Executes approved registration (controller-only)
- `rejectRegistration()`: Rejects registration with fee refund (controller-only)
- `updateController()`: Updates controller role (ENS DAO only)
- `withdrawFees()`: Withdraws accumulated fees (ENS DAO only)

**Process Flow**:

1. User submits registration request with fee
2. 7-day objection window begins
3. Controller can execute or reject the registration
4. If executed: chain registered, ChainMetadataRegistry deployed, ENS node linked

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   User Request  │───▶│   Controller     │───▶│  ChainRegistry  │
│   (with fee)    │    │   (7-day window) │    │   (main store)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                                 │                        │
                                 ▼                        ▼
                        ┌──────────────────┐    ┌─────────────────┐
                        │ChainMetadataReg  │    │   ENS Node      │
                        │   (per chain)    │    │   Resolution    │
                        └──────────────────┘    └─────────────────┘
```

## Technical Process Flow

### Chain Registration Process

```
1. Request Submission
   ├── User calls requestRegistration() with ChainData + DAO address
   ├── Pays REGISTRATION_FEE (10 ETH)
   └── Request stored with timestamp

2. Objection Window (7 days)
   ├── Community can review the request
   ├── Controller can reject at any time (with fee refund)
   └── Controller cannot execute until window expires

3. Execution Phase
   ├── Controller calls executeRegistration()
   ├── ChainMetadataRegistry clone deployed and initialized
   ├── Chain registered in ChainRegistry
   └── ENS node linked to chain ID
```

### ENS Resolution Process

```
1. User queries base.cid.eth
   ├── ENS resolves to ChainRegistry.resolve()
   └── Returns chain ID

2. Chain ID Resolution
   ├── ChainRegistry.resolveCAIP2() for CAIP-2 lookups
   ├── ChainRegistry.resolveChainName() for chain name lookups from a chain_id
   ├── ChainRegistry.resolveChainMetadataRegistry() for metadata access
   └── ChainMetadataRegistry.metadata() for chain data fields. Used to recompute chainId

3. Multi Resolve
   ├── Forward: ENS name → Chain ID (via resolve())
   ├── Reverse: Chain ID → Chain name (via resolveChainName())
   ├── CAIP-2: CAIP-2 hash → Chain ID (via resolveCAIP2())
   └── Metadata: Chain ID → Chain metadata (via resolveChainMetadataRegistry())
```

### ERC-7785 Chain Identifier Derivation

The chain ID is deterministically computed using:

```solidity
chainId = keccak256(abi.encode(
    chainName,
    settlementChainId,
    version,
    rollupContract,
    chainNamespace,
    chainReference
))
```

### Resolution Methods

The ChainRegistry provides comprehensive resolution capabilities for different use cases:

#### Forward Resolution (ENS → Chain Data)

- **`resolve(bytes32 node)`**: Resolves ENS node to chain ID
- **`resolveCAIP2(bytes32 caip2Hash)`**: Resolves CAIP-2 hash to chain ID

#### Reverse Resolution (Chain ID → Human Data)

- **`resolveChainName(bytes32 chainId)`**: Resolves chain ID to human-readable name
- **`resolveChainMetadataRegistry(bytes32 chainId)`**: Resolves chain ID to metadata registry address

#### Metadata Access

- **`metadata(bytes32 chainId)`**: Returns chain data fields for ID recomputation
- **`ChainMetadataRegistry.text(string key)`**: Retrieves chain-specific text records

#### Resolution Flow Examples

```solidity
// 1. Forward: Get chain ID from ENS name
bytes32 chainId = chainRegistry.resolve(namehash("base.cid.eth"));

// 2. Reverse: Get chain name from chain ID
string memory chainName = chainRegistry.resolveChainName(chainId);

// 3. Get metadata registry for additional data
address metadataRegistry = chainRegistry.resolveChainMetadataRegistry(chainId);

// 4. Access chain-specific metadata
string memory website = ChainMetadataRegistry(metadataRegistry).text("website");
```

## Access Control

The system uses a hierarchical role-based access control system:

### Role Hierarchy

- **ENS DAO (Owner)**: Ultimate governance control over the entire system
- **Controller**: Operational role for managing chain registrations
- **Chain-Specific DAO**: Manages individual chain metadata and governance
- **Public**: Anyone can submit registration requests

### Contract Access Control

#### ChainRegistry

- **Owner**: ENS DAO governance multisig
- **Functions**: `register()`, `linkNode()`, `bumpVersion()`, `updateChainData()`

#### ChainMetadataRegistry

- **Root Owner**: ENS DAO (immutable, can reclaim ownership)
- **DAO**: Chain-specific governance (set during initialization)
- **Functions**:
  - `setText()`, `updateDAOMultisig()` (DAO-controlled)
  - `updateRootOwner()`, `reclaimOwnership()` (ENS DAO-controlled)

#### CidRegistrarController

- **Owner**: ENS DAO governance multisig
- **Controller**: Operational role for registration management
- **Functions**:
  - `executeRegistration()`, `rejectRegistration()` (controller-only)
  - `withdrawFees()`, `updateController()` (ENS DAO only)
  - `requestRegistration()` (public)

## Version Management

### Hybrid Approach

The system handles two different types of chain updates:

#### `bumpVersion()` - Version-Only Updates

- **Purpose**: Update version string when no other attributes have changed
- **Validation**: Ensures chain ID remains the same
- **Use case**: Minor version updates, documentation changes, metadata updates
- **Chain ID**: Unchanged

#### `updateChainData()` - Full Data Updates

- **Purpose**: Update any field that affects chain ID derivation
- **Process**:
  1. Generates new chain ID from updated data
  2. Creates new registry entry with new chain ID
  3. Copies metadata registry from old chain ID
  4. Updates CAIP-2 mappings
  5. Cleans up old chain ID and mappings
- **Use case**: Protocol upgrades, rollup contract changes, major updates
- **Chain ID**: New chain ID generated
