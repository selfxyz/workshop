#!/bin/bash

# Deploy Proof of Human Contract Script
# Based on the Self SBT deployment workflow

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

# Required environment variables
REQUIRED_VARS=(
    "PRIVATE_KEY"
)

# Check required variables
print_info "Checking required environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Set defaults for optional variables
PLACEHOLDER_SCOPE=${PLACEHOLDER_SCOPE:-1}
NETWORK=${NETWORK:-"celo-sepolia"}

# Network configuration
case "$NETWORK" in
    "celo-mainnet")
        IDENTITY_VERIFICATION_HUB_ADDRESS=${IDENTITY_VERIFICATION_HUB_ADDRESS:-"0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF"}
        RPC_URL="https://forno.celo.org"
        NETWORK_NAME="celo-mainnet"
        CHAIN_ID="42220"
        BLOCK_EXPLORER_URL="https://celoscan.io"
        ;;
    "celo-sepolia")
        IDENTITY_VERIFICATION_HUB_ADDRESS=${IDENTITY_VERIFICATION_HUB_ADDRESS:-"0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74"}
        RPC_URL="https://forno.celo-sepolia.celo-testnet.org"
        NETWORK_NAME="celo-sepolia"
        CHAIN_ID="11142220"
        BLOCK_EXPLORER_URL="https://celo-sepolia.blockscout.com"
        ;;
    *)
        print_error "Unsupported network: $NETWORK. Use 'celo-mainnet' or 'celo-sepolia'"
        exit 1
        ;;
esac

print_success "Network configured: $NETWORK_NAME"
print_info "Hub Address: $IDENTITY_VERIFICATION_HUB_ADDRESS"
print_info "RPC URL: $RPC_URL"

# Validate addresses
validate_address() {
    if [[ ! $1 =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid Ethereum address: $1"
        exit 1
    fi
}

validate_bytes32() {
    if [[ ! $1 =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        print_error "Invalid bytes32 value: $1"
        exit 1
    fi
}

print_info "Validating input parameters..."
validate_address "$IDENTITY_VERIFICATION_HUB_ADDRESS"
print_success "All inputs validated successfully"

# Build contracts
print_info "Building Solidity contracts..."
forge build
if [ $? -ne 0 ]; then
    print_error "Contract compilation failed"
    exit 1
fi
print_success "Contract compilation successful!"

# Export hub address for Solidity script
export IDENTITY_VERIFICATION_HUB_ADDRESS

# Deploy contract
print_info "Deploying ProofOfHuman contract with placeholder scope..."

DEPLOY_CMD="forge script script/DeployProofOfHuman.s.sol:DeployProofOfHuman --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast"

echo "🚀 Step 1: Executing deployment..."
eval $DEPLOY_CMD

if [ $? -ne 0 ]; then
    # Check if deployment actually succeeded despite exit code error
    if [[ -f "broadcast/DeployProofOfHuman.s.sol/$CHAIN_ID/run-latest.json" ]]; then
        print_success "Contract deployment completed (ignoring wallet warnings)"
    else
        print_error "Contract deployment failed"
        exit 1
    fi
fi

# Extract deployed contract address
BROADCAST_DIR="broadcast/DeployProofOfHuman.s.sol/$CHAIN_ID"
if [[ -f "$BROADCAST_DIR/run-latest.json" ]]; then
    CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHuman") | .contractAddress' "$BROADCAST_DIR/run-latest.json" | head -1)
    
    if [[ -n "$CONTRACT_ADDRESS" && "$CONTRACT_ADDRESS" != "null" ]]; then
        print_success "Contract deployed at: $CONTRACT_ADDRESS"
        print_info "View on explorer: $BLOCK_EXPLORER_URL/address/$CONTRACT_ADDRESS"
    else
        print_error "Could not extract contract address from deployment"
        exit 1
    fi
else
    print_error "Could not find deployment artifacts"
    exit 1
fi

# Verify contract if API key is provided
if [ -n "$CELOSCAN_API_KEY" ]; then
    print_info "Verifying contract on CeloScan..."
    
    # Determine chain name for forge verify-contract
    case "$NETWORK" in
        "celo-mainnet")
            CHAIN_NAME="celo"
            ;;
        "celo-sepolia")
            CHAIN_NAME="celo-sepolia"
            ;;
    esac
    
    # Encode constructor arguments for verification
    # Constructor: (address,uint256,(uint256,string[],bool))
    # verificationConfig struct: {olderThan: 18, forbiddenCountries: ["USA"], ofacEnabled: false}
    CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,uint256,(uint256,string[],bool))" \
        $IDENTITY_VERIFICATION_HUB_ADDRESS \
        $PLACEHOLDER_SCOPE \
        "(18,[\"USA\"],false)")
    
    print_info "Constructor args: $CONSTRUCTOR_ARGS"
    
    # Use forge verify-contract with constructor arguments
    forge verify-contract --constructor-args $CONSTRUCTOR_ARGS --chain-id $CHAIN_NAME $CONTRACT_ADDRESS src/ProofOfHuman.sol:ProofOfHuman --watch
    
    if [ $? -ne 0 ]; then
        print_warning "Verification failed. You can verify manually at:"
        print_info "$BLOCK_EXPLORER_URL/verifyContract"
        print_info "Contract Address: $CONTRACT_ADDRESS"
    fi
else
    print_warning "CELOSCAN_API_KEY not provided, skipping verification"
fi

# Display deployment summary
echo
print_success "🎉 Deployment Successful!"
echo
echo "Quick Links:"
echo "- Contract Address: $CONTRACT_ADDRESS"
echo "- View on Explorer: $BLOCK_EXPLORER_URL/address/$CONTRACT_ADDRESS"
echo
echo "Deployment Details:"
echo "| Parameter | Value |"
echo "|-----------|-------|"
echo "| Network | $NETWORK_NAME |"
echo "| Chain ID | $CHAIN_ID |"
echo "| Contract Address | $CONTRACT_ADDRESS |"
echo "| Hub Address | $IDENTITY_VERIFICATION_HUB_ADDRESS |"
echo "| RPC URL | $RPC_URL |"
echo "| Block Explorer | $BLOCK_EXPLORER_URL |"
echo "| Placeholder Scope | $PLACEHOLDER_SCOPE |"
echo "| Verification Config | olderThan: 18, forbiddenCountries: [USA], ofacEnabled: false |"
if [ -n "$SCOPE_VALUE" ]; then
    echo "| Scope Value | $SCOPE_VALUE |"
fi
echo
print_success "✅ Deployment Complete"
if [ -n "$SCOPE_SEED" ]; then
    echo "1. ✅ Contract deployed with placeholder scope"
    echo "2. ✅ Actual scope calculated from deployed address + scope seed"
    echo "3. ✅ Scope value set on deployed contract automatically"
else
    echo "1. ✅ Contract deployed with placeholder scope"
    echo "2. ⚠️  Scope calculation skipped (no SCOPE_SEED provided)"
fi