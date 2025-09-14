#!/bin/bash

# Manual Contract Verification Script
# Use this if automatic verification during deployment fails
# Verifies ProofOfHumanOApp on Celo and ProofOfHumanReceiver on Base Mainnet

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
REQUIRED_VARS=("PRIVATE_KEY" "CELOSCAN_API_KEY" "BASESCAN_API_KEY" "VERIFICATION_CONFIG_ID")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Constants
CELO_HUB_ADDRESS="0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF"
LZ_ENDPOINT_ADDRESS="0x1a44076050125825900e736c501f859c50fE728c"
PLACEHOLDER_SCOPE=${PLACEHOLDER_SCOPE:-1}

# Get deployer address
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)

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

# Encode constructor arguments
print_info "Encoding constructor arguments..."

CELO_CONSTRUCTOR_ARGS=$(cast abi-encode \
    "constructor(address,uint256,bytes32,address,address)" \
    "$CELO_HUB_ADDRESS" \
    "$PLACEHOLDER_SCOPE" \
    "$VERIFICATION_CONFIG_ID" \
    "$LZ_ENDPOINT_ADDRESS" \
    "$DEPLOYER")

BASE_CONSTRUCTOR_ARGS=$(cast abi-encode \
    "constructor(address,address)" \
    "$LZ_ENDPOINT_ADDRESS" \
    "$DEPLOYER")

print_info "Starting manual contract verification..."

# Track overall success
CELO_SUCCESS=false
BASE_SUCCESS=false

# Verify ProofOfHumanOApp on Celo Mainnet
print_info "Verifying ProofOfHumanOApp on Celo Mainnet..."
print_info "Waiting 10 seconds for block explorer to index..."
sleep 10

for i in {1..3}; do
    if forge verify-contract \
        --verifier etherscan \
        --verifier-url "https://api.celoscan.io/v2/api?chainid=42220" \
        --etherscan-api-key "$CELOSCAN_API_KEY" \
        --constructor-args "$CELO_CONSTRUCTOR_ARGS" \
        --num-of-optimizations 10000 \
        --compiler-version 0.8.28 \
        "$SOURCE_CONTRACT_ADDRESS" \
        src/ProofOfHumanOApp.sol:ProofOfHumanOApp \
        --watch 2>&1 | tee /dev/stderr | grep -qi "successfully verified\|already verified"; then
        CELO_SUCCESS=true
        break
    fi
    if [ $i -lt 3 ]; then
        print_info "Celo verification not ready yet, waiting 20s and retrying (attempt $i/3)..."
        sleep 20
    fi
done

if [ "$CELO_SUCCESS" = true ]; then
    print_success "ProofOfHumanOApp verified on Celo Mainnet"
    print_info "View at: https://celoscan.io/address/$SOURCE_CONTRACT_ADDRESS#code"
else
    print_warning "ProofOfHumanOApp verification failed - check manually at:"
    print_info "https://celoscan.io/address/$SOURCE_CONTRACT_ADDRESS#code"
fi

echo

# Verify ProofOfHumanReceiver on Base Mainnet
print_info "Verifying ProofOfHumanReceiver on Base Mainnet..."
print_info "Waiting 10 seconds for block explorer to index..."
sleep 10

for i in {1..3}; do
    if forge verify-contract \
        --verifier etherscan \
        --verifier-url "https://api.basescan.org/v2/api?chainid=8453" \
        --etherscan-api-key "$BASESCAN_API_KEY" \
        --constructor-args "$BASE_CONSTRUCTOR_ARGS" \
        --num-of-optimizations 10000 \
        --compiler-version 0.8.28 \
        "$DEST_CONTRACT_ADDRESS" \
        src/ProofOfHumanReceiver.sol:ProofOfHumanReceiver \
        --watch 2>&1 | tee /dev/stderr | grep -qi "successfully verified\|already verified"; then
        BASE_SUCCESS=true
        break
    fi
    if [ $i -lt 3 ]; then
        print_info "Base verification not ready yet, waiting 20s and retrying (attempt $i/3)..."
        sleep 20
    fi
done

if [ "$BASE_SUCCESS" = true ]; then
    print_success "ProofOfHumanReceiver verified on Base Mainnet"
    print_info "View at: https://basescan.org/address/$DEST_CONTRACT_ADDRESS#code"
else
    print_warning "ProofOfHumanReceiver verification failed - check manually at:"
    print_info "https://basescan.org/address/$DEST_CONTRACT_ADDRESS#code"
fi

echo

# Final summary
if [ "$CELO_SUCCESS" = true ] && [ "$BASE_SUCCESS" = true ]; then
    print_success "All contracts verified successfully!"
elif [ "$CELO_SUCCESS" = true ] || [ "$BASE_SUCCESS" = true ]; then
    print_warning "Partial verification - check failed contracts manually."
else
    print_error "Verification failed for both contracts. Check the errors above."
fi
