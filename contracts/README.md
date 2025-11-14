# Smart Contracts

This folder contains the Solidity smart contracts for the Self Protocol Workshop, built with Foundry.

## Overview

The `ProofOfHuman` contract demonstrates privacy-preserving identity verification using the [Self Protocol](https://self.xyz/). It extends `SelfVerificationRoot` to verify users through passport-based attestations without revealing sensitive personal information on-chain.

### Key Features

- 🔐 Privacy-preserving identity verification
- ✅ Age verification (18+)
- 🌍 Country restriction enforcement
- 📱 Integration with Self Mobile App
- ⛓️ Deployed on Celo (testnet and mainnet)

### Project Structure

```
contracts/
├── src/
│   └── ProofOfHuman.sol          # Main contract implementation
├── script/
│   ├── DeployProofOfHuman.s.sol  # Foundry deployment script
│   ├── deploy-proof-of-human.sh  # Automated deployment script
│   └── Base.s.sol                # Base script utilities
├── lib/
│   ├── forge-std/                # Foundry standard library
│   └── openzeppelin-contracts/   # OpenZeppelin contracts
├── .env.example                  # Environment variables template
└── foundry.toml                  # Foundry configuration
```

## Quick Start

### 1. Install Dependencies

```shell
npm install
forge install
```

### 2. Configure Environment

```shell
cp .env.example .env
```

Edit `.env` with your values:
```bash
PRIVATE_KEY=0xyour_private_key_here
NETWORK=celo-sepolia
SCOPE_SEED="self-workshop"
```

### 3. Deploy Contract

```shell
# Deploy to Celo Sepolia testnet
./script/deploy-proof-of-human.sh
```

The deployment script will:
- Build the contracts
- Deploy ProofOfHuman to the selected network
- Verify the contract on the block explorer
- Display deployment information

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Network Configuration

### Celo Sepolia (Testnet)
- **Hub Address**: `0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74`
- **RPC**: `https://forno.celo-sepolia.celo-testnet.org`
- **Explorer**: `https://celo-sepolia.blockscout.com/`
- **Use for**: Testing with mock passports

### Celo Mainnet
- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`
- **RPC**: `https://forno.celo.org`
- **Explorer**: `https://celoscan.io`
- **Use for**: Production with real passport verification

## Contract Details

The `ProofOfHuman` contract includes:

- **Verification Storage**: Stores verification results and user data
- **Configuration Management**: Manages verification requirements (age, country restrictions)
- **Custom Hook**: Implements `customVerificationHook` to process successful verifications
- **Events**: Emits `VerificationCompleted` events for tracking

### Verification Configuration

The contract is configured to require:
- Minimum age: 18 years old
- Forbidden countries: United States (configurable)
- OFAC compliance: Disabled by default