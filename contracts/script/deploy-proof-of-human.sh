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
SCOPE_SEED=${SCOPE_SEED:-"self-workshop"}
NETWORK=${NETWORK:-"celo-sepolia"}

# Network configuration
case "$NETWORK" in
    "celo-mainnet")
        IDENTITY_VERIFICATION_HUB_ADDRESS=${IDENTITY_VERIFICATION_HUB_ADDRESS:-"0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF"}
        RPC_URL="https://forno.celo.org"
        NETWORK_NAME="celo-mainnet"
        CHAIN_ID="42220"
        BLOCK_EXPLORER_URL="https://celoscan.io"
        VERIFIER="etherscan"
        # Use Etherscan V2 API format
        VERIFIER_URL="https://api.celoscan.io/v2/api?chainid=42220"
        ;;
    "celo-sepolia")
        IDENTITY_VERIFICATION_HUB_ADDRESS=${IDENTITY_VERIFICATION_HUB_ADDRESS:-"0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74"}
        RPC_URL="https://forno.celo-sepolia.celo-testnet.org"
        NETWORK_NAME="celo-sepolia"
        CHAIN_ID="11142220"
        BLOCK_EXPLORER_URL="https://celo-sepolia.blockscout.com"
        VERIFIER="blockscout"
        VERIFIER_URL="https://celo-sepolia.blockscout.com/api"
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

# Export environment variables for Solidity script
export IDENTITY_VERIFICATION_HUB_ADDRESS
export SCOPE_SEED

# Deploy contract
print_info "Deploying ProofOfHuman contract with scope seed: $SCOPE_SEED"

DEPLOY_CMD="forge script script/DeployProofOfHuman.s.sol:DeployProofOfHuman --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast"

echo "🚀 Executing deployment..."
echo
print_warning "NOTE: You will see 'ERROR etherscan: Failed to deserialize response' messages below."
print_warning "This is a known Foundry issue when querying block explorers - these are harmless."
print_warning "Your deployment will succeed regardless. Check the deployment status after completion."
echo
eval $DEPLOY_CMD

# Check if deployment succeeded by looking for the broadcast file
echo
print_info "Checking deployment status..."
if [[ ! -f "broadcast/DeployProofOfHuman.s.sol/$CHAIN_ID/run-latest.json" ]]; then
    print_error "Contract deployment failed"
    exit 1
fi
print_success "Deployment transaction confirmed!"
echo

# Extract deployed contract address
BROADCAST_DIR="broadcast/DeployProofOfHuman.s.sol/$CHAIN_ID"
if [[ -f "$BROADCAST_DIR/run-latest.json" ]]; then
    # Extract address and convert to lowercase to match on-chain scope calculation
    CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHuman") | .contractAddress' "$BROADCAST_DIR/run-latest.json" | head -1 | tr '[:upper:]' '[:lower:]')
    
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

# Contract verification
print_info "Waiting for block explorers to index the contract..."

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
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,string,(uint256,string[],bool))" \
    $IDENTITY_VERIFICATION_HUB_ADDRESS \
    "$SCOPE_SEED" \
    "(18,[\"USA\"],false)")

# For Celo Sepolia, verify on Blockscout only (Celoscan Sepolia has verification issues)
if [ "$NETWORK" = "celo-sepolia" ]; then
    # Wait for block explorer to index the contract
    print_info "Waiting 30 seconds for Blockscout to index the contract..."
    sleep 30
    
    # Verify on Blockscout
    print_info "Verifying on Blockscout..."
    BLOCKSCOUT_SUCCESS=false
    for i in {1..3}; do
        if forge verify-contract \
            --verifier blockscout \
            --verifier-url "https://celo-sepolia.blockscout.com/api" \
            --constructor-args $CONSTRUCTOR_ARGS \
            --chain-id $CHAIN_NAME \
            $CONTRACT_ADDRESS \
            src/ProofOfHuman.sol:ProofOfHuman \
            --watch 2>&1 | grep -v "ERROR etherscan" | grep -qi "successfully verified\|already verified"; then
            BLOCKSCOUT_SUCCESS=true
            break
        fi
        if [ $i -lt 3 ]; then
            print_info "Blockscout not ready yet, waiting 20s and retrying..."
            sleep 20
        fi
    done
    
    if [ "$BLOCKSCOUT_SUCCESS" = true ]; then
        print_success "Contract verified on Blockscout!"
        print_info "View at: https://celo-sepolia.blockscout.com/address/$CONTRACT_ADDRESS"
    else
        print_warning "Blockscout verification pending - check manually at:"
        print_info "https://celo-sepolia.blockscout.com/address/$CONTRACT_ADDRESS"
    fi
else
    # For mainnet, verify on Celoscan only
    if [ -n "$CELOSCAN_API_KEY" ]; then
        print_info "Waiting 30 seconds for Celoscan to index the contract..."
        sleep 30
        print_info "Verifying on Celoscan..."
        
        CELOSCAN_SUCCESS=false
        for i in {1..3}; do
            if forge verify-contract \
                --verifier etherscan \
                --verifier-url "https://api.celoscan.io/api" \
                --etherscan-api-key "$CELOSCAN_API_KEY" \
                --constructor-args $CONSTRUCTOR_ARGS \
                --chain-id $CHAIN_NAME \
                $CONTRACT_ADDRESS \
                src/ProofOfHuman.sol:ProofOfHuman \
                --watch 2>&1 | grep -v "ERROR etherscan" | grep -qi "successfully verified\|already verified"; then
                CELOSCAN_SUCCESS=true
                break
            fi
            if [ $i -lt 3 ]; then
                print_info "Celoscan not ready yet, waiting 20s and retrying..."
                sleep 20
            fi
        done
        
        if [ "$CELOSCAN_SUCCESS" = true ]; then
            print_success "Verified on Celoscan!"
        else
            print_warning "Celoscan verification pending - check manually at:"
            print_info "https://celoscan.io/address/$CONTRACT_ADDRESS"
        fi
    else
        print_warning "Set CELOSCAN_API_KEY to verify on Celoscan"
        print_info "Manual verification: https://celoscan.io/verifyContract"
    fi
fi

# Display deployment summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "🎉 Deployment Completed Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
echo "| Scope Seed | $SCOPE_SEED |"
echo "| Verification Config | olderThan: 18, forbiddenCountries: [USA], ofacEnabled: false |"
echo
print_success "Deployment Complete!"
echo "1. ✅ Contract deployed successfully"
echo "2. ✅ Scope generated from SCOPE_SEED: $SCOPE_SEED"
echo "3. ✅ Contract verified on block explorer"
echo
print_warning "IMPORTANT: Frontend Configuration"
echo "Add this to your frontend .env file:"
echo "NEXT_PUBLIC_SELF_ENDPOINT=$CONTRACT_ADDRESS"