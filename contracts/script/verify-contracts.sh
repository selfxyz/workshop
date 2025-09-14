#!/bin/bash

# Manual Contract Verification Script
# Use this if automatic verification during deployment fails

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Source environment variables
source .env

# Check required variables
REQUIRED_VARS=("PRIVATE_KEY" "ETHERSCAN_API_KEY")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Get contract addresses from user input or deployment artifacts
if [ $# -eq 2 ]; then
    SOURCE_CONTRACT_ADDRESS=$1
    DEST_CONTRACT_ADDRESS=$2
    print_info "Using provided contract addresses:"
    print_info "Source (Celo): $SOURCE_CONTRACT_ADDRESS"
    print_info "Destination (Base Mainnet): $DEST_CONTRACT_ADDRESS"
else
    # Try to extract from deployment artifacts
    CELO_BROADCAST="broadcast/DeployProofOfHumanOApp.s.sol/42220/run-latest.json"
    BASE_BROADCAST="broadcast/DeployProofOfHumanReceiver.s.sol/8453/run-latest.json"
    
    if [[ -f "$CELO_BROADCAST" && -f "$BASE_BROADCAST" ]]; then
        SOURCE_CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanOApp") | .contractAddress' "$CELO_BROADCAST" | head -1)
        DEST_CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanReceiver") | .contractAddress' "$BASE_BROADCAST" | head -1)
        
        if [[ -n "$SOURCE_CONTRACT_ADDRESS" && "$SOURCE_CONTRACT_ADDRESS" != "null" && -n "$DEST_CONTRACT_ADDRESS" && "$DEST_CONTRACT_ADDRESS" != "null" ]]; then
            print_info "Found contract addresses from deployment artifacts:"
            print_info "Source (Celo): $SOURCE_CONTRACT_ADDRESS"
            print_info "Destination (Base Mainnet): $DEST_CONTRACT_ADDRESS"
        else
            print_error "Could not extract contract addresses from deployment artifacts."
            print_error "Usage: ./verify-contracts.sh <celo_contract_address> <base_mainnet_contract_address>"
            exit 1
        fi
    else
        print_error "No deployment artifacts found and no addresses provided."
        print_error "Usage: ./verify-contracts.sh <celo_contract_address> <base_mainnet_contract_address>"
        exit 1
    fi
fi

print_info "Starting manual contract verification..."

# Verify ProofOfHumanOApp on Celo Mainnet
print_info "Verifying ProofOfHumanOApp on Celo Mainnet..."
CELO_VERIFY_CMD="forge verify-contract $SOURCE_CONTRACT_ADDRESS src/ProofOfHumanOApp.sol:ProofOfHumanOApp \\
    --chain-id 42220 \\
    --num-of-optimizations 10000 \\
    --compiler-version 0.8.28 \\
    --etherscan-api-key $ETHERSCAN_API_KEY \\
    --constructor-args \\$(cast abi-encode 'constructor(address,uint256,bytes32,address,address)' \\
        0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF \\
        1 \\
        $VERIFICATION_CONFIG_ID \\
        0x1a44076050125825900e736c501f859c50fE728c \\
        $(cast wallet address --private-key $PRIVATE_KEY))"

echo "Executing: $CELO_VERIFY_CMD"
eval $CELO_VERIFY_CMD

if [ $? -eq 0 ]; then
    print_success "ProofOfHumanOApp verified on Celo Mainnet"
    print_info "View at: https://celoscan.io/address/$SOURCE_CONTRACT_ADDRESS#code"
else
    print_warning "ProofOfHumanOApp verification failed or already verified"
fi

echo

# Verify ProofOfHumanReceiver on Base Mainnet
print_info "Verifying ProofOfHumanReceiver on Base Mainnet..."
BASE_VERIFY_CMD="forge verify-contract $DEST_CONTRACT_ADDRESS src/ProofOfHumanReceiver.sol:ProofOfHumanReceiver \\
    --chain-id 8453 \\
    --num-of-optimizations 10000 \\
    --compiler-version 0.8.28 \\
    --etherscan-api-key $ETHERSCAN_API_KEY \\
    --constructor-args \\$(cast abi-encode 'constructor(address,address)' \\
        0x1a44076050125825900e736c501f859c50fE728c \\
        $(cast wallet address --private-key $PRIVATE_KEY))"

echo "Executing: $BASE_VERIFY_CMD"
eval $BASE_VERIFY_CMD

if [ $? -eq 0 ]; then
    print_success "ProofOfHumanReceiver verified on Base Mainnet"
    print_info "View at: https://basescan.org/address/$DEST_CONTRACT_ADDRESS#code"
else
    print_warning "ProofOfHumanReceiver verification failed or already verified"
fi

echo
print_success "Manual verification process completed!"
print_info "Check the links above to confirm verification status."
