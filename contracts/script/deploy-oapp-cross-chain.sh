#!/bin/bash

# Deploy Cross-Chain Proof of Human OApp Script
# Deploys ProofOfHumanOApp on Celo and ProofOfHumanReceiver on Base Mainnet

# Don't exit immediately on error for peer setup - we want to continue with frontend config
# set -e  # Exit on error

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

# Retry function with exponential backoff
retry_command() {
    local cmd="$1"
    local description="$2"
    local max_attempts="${3:-3}"
    local wait_time="${4:-5}"

    for attempt in $(seq 1 $max_attempts); do
        print_info "Attempt $attempt/$max_attempts: $description"

        if eval "$cmd"; then
            return 0
        else
            local exit_code=$?
            if [ $attempt -eq $max_attempts ]; then
                print_error "Failed after $max_attempts attempts: $description"
                return $exit_code
            else
                print_warning "Attempt $attempt failed, retrying in ${wait_time}s..."
                sleep $wait_time
                # Exponential backoff
                wait_time=$((wait_time * 2))
            fi
        fi
    done
}

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
    "VERIFICATION_CONFIG_ID"
    "SCOPE_SEED"
)

# Check required variables
print_info "Checking required environment variables..."
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        print_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Set defaults - Celo Mainnet -> Base Mainnet
PLACEHOLDER_SCOPE=${PLACEHOLDER_SCOPE:-1}
SOURCE_NETWORK="celo-mainnet"
DESTINATION_NETWORK="base-mainnet"

# Configuration flags
AUTO_SETUP_PEERS=${AUTO_SETUP_PEERS:-true}
AUTO_FUND_SOURCE=${AUTO_FUND_SOURCE:-false}
FUND_AMOUNT=${FUND_AMOUNT:-"0.01"}
VERIFY_CONTRACTS=${VERIFY_CONTRACTS:-false}

print_success "Environment variables validated"

# Preflight: check deployer balances on both chains to avoid mid-script failures
print_info "Checking deployer balances on Celo and Base..."
DEPLOYER=$(cast wallet address --private-key $PRIVATE_KEY)
CELO_BAL_WEI=$(cast balance $DEPLOYER --rpc-url https://forno.celo.org)
BASE_BAL_WEI=$(cast balance $DEPLOYER --rpc-url https://mainnet.base.org)
CELO_BAL=$(cast --from-wei $CELO_BAL_WEI)
BASE_BAL=$(cast --from-wei $BASE_BAL_WEI)
echo "Deployer: $DEPLOYER"
echo "Celo balance: $CELO_BAL CELO"
echo "Base balance: $BASE_BAL ETH"

# Require at least 0.20 CELO and 0.0001 ETH (rough guidance; adjust as needed)
MIN_CELO_WEI=200000000000000000      # 0.20 CELO
MIN_BASE_WEI=100000000000000         # 0.0001 ETH
if [ "$CELO_BAL_WEI" -lt "$MIN_CELO_WEI" ]; then
  print_error "Insufficient CELO for deployment (need >= 0.20 CELO). Fund $DEPLOYER on Celo Mainnet."
  exit 1
fi
if [ "$BASE_BAL_WEI" -lt "$MIN_BASE_WEI" ]; then
  print_error "Insufficient ETH on Base for deployment (need >= 0.0001 ETH). Fund $DEPLOYER on Base Mainnet."
  exit 1
fi

# Hardcode destination EID if not provided
DESTINATION_EID=${DESTINATION_EID:-30184}

# Network-specific configurations
setup_network_config() {
    local network=$1
    
    case "$network" in
        "celo-mainnet")
            IDENTITY_VERIFICATION_HUB_ADDRESS=${IDENTITY_VERIFICATION_HUB_ADDRESS:-"0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF"}
            LAYERZERO_ENDPOINT_ADDRESS="0x1a44076050125825900e736c501f859c50fE728c"
            RPC_URL="https://forno.celo.org"
            NETWORK_NAME="celo-mainnet"
            CHAIN_ID="42220"
            BLOCK_EXPLORER_URL="https://celoscan.io"
            ;;
        "celo-alfajores")
            print_error "Celo Alfajores testnet is not supported by LayerZero V2. Use celo-mainnet instead."
            exit 1
            ;;
        "base-mainnet")
            # Hardcoded Base Mainnet LayerZero Endpoint V2 address
            LAYERZERO_ENDPOINT_ADDRESS="0x1a44076050125825900e736c501f859c50fE728c"
            RPC_URL="https://mainnet.base.org"
            NETWORK_NAME="base-mainnet"
            CHAIN_ID="8453"
            BLOCK_EXPLORER_URL="https://basescan.org"
            ;;
        *)
            print_error "Unsupported network: $network"
            exit 1
            ;;
    esac
    
    export IDENTITY_VERIFICATION_HUB_ADDRESS
    export LAYERZERO_ENDPOINT_ADDRESS
}

# Build contracts
print_info "Building Solidity contracts..."
forge build
if [ $? -ne 0 ]; then
    print_error "Contract compilation failed"
    exit 1
fi
print_success "Contract compilation successful!"

# Deploy on source chain (Celo)
print_info "Deploying ProofOfHumanOApp on source chain: $SOURCE_NETWORK"
setup_network_config "$SOURCE_NETWORK"

print_info "Using LayerZero Endpoint: $LAYERZERO_ENDPOINT_ADDRESS"
print_info "Using Hub Address: $IDENTITY_VERIFICATION_HUB_ADDRESS"

# Build deployment command with optional verification
if [ "$VERIFY_CONTRACTS" = "true" ]; then
    SOURCE_DEPLOY_CMD="forge script script/DeployProofOfHumanOApp.s.sol:DeployProofOfHumanOApp --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --slow"
else
    SOURCE_DEPLOY_CMD="forge script script/DeployProofOfHumanOApp.s.sol:DeployProofOfHumanOApp --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow"
fi

echo "🚀 Step 1: Deploying on source chain ($SOURCE_NETWORK)..."
eval $SOURCE_DEPLOY_CMD

if [ $? -ne 0 ]; then
    print_error "Source chain deployment failed"
    exit 1
fi

# Extract source contract address
SOURCE_BROADCAST_DIR="broadcast/DeployProofOfHumanOApp.s.sol/$CHAIN_ID"
if [[ -f "$SOURCE_BROADCAST_DIR/run-latest.json" ]]; then
    SOURCE_CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanOApp") | .contractAddress' "$SOURCE_BROADCAST_DIR/run-latest.json" | head -1)
    
    if [[ -n "$SOURCE_CONTRACT_ADDRESS" && "$SOURCE_CONTRACT_ADDRESS" != "null" ]]; then
        # Convert to checksum format immediately
    SOURCE_CONTRACT_ADDRESS_CHECKSUM=$(cast to-checksum-address "$SOURCE_CONTRACT_ADDRESS" 2>/dev/null || true)
    if [ -z "$SOURCE_CONTRACT_ADDRESS_CHECKSUM" ]; then
        print_warning "Checksum conversion failed with cast; using original address"
        SOURCE_CONTRACT_ADDRESS_CHECKSUM="$SOURCE_CONTRACT_ADDRESS"
    fi
        print_success "ProofOfHumanOApp deployed at: $SOURCE_CONTRACT_ADDRESS_CHECKSUM"
    else
        print_error "Could not extract source contract address"
        exit 1
    fi
else
    print_error "Could not find source deployment artifacts"
    exit 1
fi

# Deploy on destination chain (Base)
print_info "Deploying ProofOfHumanReceiver on destination chain: $DESTINATION_NETWORK"
setup_network_config "$DESTINATION_NETWORK"

print_info "Using LayerZero Endpoint: $LAYERZERO_ENDPOINT_ADDRESS"

# Build destination deployment command with optional verification
if [ "$VERIFY_CONTRACTS" = "true" ]; then
    DEST_DEPLOY_CMD="forge script script/DeployProofOfHumanReceiver.s.sol:DeployProofOfHumanReceiver --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY --slow"
else
    DEST_DEPLOY_CMD="forge script script/DeployProofOfHumanReceiver.s.sol:DeployProofOfHumanReceiver --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --slow"
fi

echo "🚀 Step 2: Deploying on destination chain ($DESTINATION_NETWORK)..."
eval $DEST_DEPLOY_CMD

if [ $? -ne 0 ]; then
    print_error "Destination chain deployment failed"
    exit 1
fi

# Extract destination contract address
DEST_BROADCAST_DIR="broadcast/DeployProofOfHumanReceiver.s.sol/$CHAIN_ID"
if [[ -f "$DEST_BROADCAST_DIR/run-latest.json" ]]; then
    DEST_CONTRACT_ADDRESS=$(jq -r '.transactions[] | select(.contractName == "ProofOfHumanReceiver") | .contractAddress' "$DEST_BROADCAST_DIR/run-latest.json" | head -1)
    
    if [[ -n "$DEST_CONTRACT_ADDRESS" && "$DEST_CONTRACT_ADDRESS" != "null" ]]; then
        print_success "ProofOfHumanReceiver deployed at: $DEST_CONTRACT_ADDRESS"
    else
        print_error "Could not extract destination contract address"
        exit 1
    fi
else
    print_error "Could not find destination deployment artifacts"
    exit 1
fi

# Calculate and set scope if SCOPE_SEED is provided
if [ -n "$SCOPE_SEED" ]; then
    print_info "Calculating and setting scope using deployed address..."
    
    setup_network_config "$SOURCE_NETWORK"
    
    # Calculate scope value
    SCOPE_VALUE=$(node -e "
      try {
        const core = require('@selfxyz/core');
        const fn = core.hashEndpointWithScope || (core.default && core.default.hashEndpointWithScope);
        if (!fn) throw new Error('hashEndpointWithScope not found');
        const hash = fn('$SOURCE_CONTRACT_ADDRESS_CHECKSUM', '$SCOPE_SEED');
        console.log(hash);
      } catch (error) {
        console.error('WARN: Scope calc failed, falling back to PLACEHOLDER_SCOPE:', error.message);
      }
    ")
    if [ -z "$SCOPE_VALUE" ]; then
        SCOPE_VALUE=${PLACEHOLDER_SCOPE}
        print_warning "Using PLACEHOLDER_SCOPE=$SCOPE_VALUE. You can set it later via setScope(uint256)."
    fi
    
    print_success "Calculated scope value: $SCOPE_VALUE"
    
    # Set scope on source contract
    print_info "Setting scope value on ProofOfHumanOApp..."
    cast send $SOURCE_CONTRACT_ADDRESS "setScope(uint256)" $SCOPE_VALUE --rpc-url $RPC_URL --private-key $PRIVATE_KEY
    
    if [ $? -eq 0 ]; then
        print_success "Scope value set successfully!"
    else
        print_warning "Failed to call setScope automatically"
    fi
fi

# Display deployment summary
echo
print_success "🎉 Cross-Chain Deployment Successful!"
echo
echo "📋 Deployment Summary:"
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ SOURCE CHAIN ($SOURCE_NETWORK)"
echo "├─────────────────────────────────────────────────────────────────┤"
echo "│ Contract: ProofOfHumanOApp"
echo "│ Address:  $SOURCE_CONTRACT_ADDRESS_CHECKSUM"
echo "│ Explorer: $(setup_network_config "$SOURCE_NETWORK" && echo $BLOCK_EXPLORER_URL)/address/$SOURCE_CONTRACT_ADDRESS_CHECKSUM"
echo "├─────────────────────────────────────────────────────────────────┤"
echo "│ DESTINATION CHAIN ($DESTINATION_NETWORK)"
echo "├─────────────────────────────────────────────────────────────────┤"
echo "│ Contract: ProofOfHumanReceiver"
echo "│ Address:  $DEST_CONTRACT_ADDRESS"
echo "│ Explorer: $(setup_network_config "$DESTINATION_NETWORK" && echo $BLOCK_EXPLORER_URL)/address/$DEST_CONTRACT_ADDRESS"
echo "└─────────────────────────────────────────────────────────────────┘"
echo
# Automatic LayerZero peer setup
AUTO_SETUP_PEERS=${AUTO_SETUP_PEERS:-true}
AUTO_FUND_SOURCE=${AUTO_FUND_SOURCE:-false}
FUND_AMOUNT=${FUND_AMOUNT:-"0.01"}

if [ "$AUTO_SETUP_PEERS" = "true" ]; then
    echo
    print_info "🔗 Setting up LayerZero peers with retry logic..."

    # Prepare variables for peer setup
    setup_network_config "$SOURCE_NETWORK"
    DEST_BYTES32=$(cast --to-bytes32 $DEST_CONTRACT_ADDRESS)
    SOURCE_EID_DEFAULT=30125
    SOURCE_EID_EFFECTIVE=${SOURCE_EID:-$SOURCE_EID_DEFAULT}
    CELO_MAINNET_BYTES32=$(cast --to-bytes32 $SOURCE_CONTRACT_ADDRESS)

    # Set destination as peer on Celo Mainnet with retry
    setup_network_config "$SOURCE_NETWORK"
    print_info "Step 1/2: Setting Base as peer on Celo contract..."

    CELO_PEER_CMD="cast send $SOURCE_CONTRACT_ADDRESS 'setPeer(uint32,bytes32)' ${DESTINATION_EID} $DEST_BYTES32 --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --confirmations 1"

    if retry_command "$CELO_PEER_CMD" "Set peer on Celo" 3 8; then
        print_success "✅ Peer set on Celo Mainnet: ${DESTINATION_EID} -> $DEST_CONTRACT_ADDRESS"
        CELO_PEER_SUCCESS=true
    else
        print_error "❌ Failed to set peer on Celo Mainnet after retries"
        CELO_PEER_SUCCESS=false
    fi

    # Set Celo Mainnet as peer on destination with retry
    setup_network_config "$DESTINATION_NETWORK"
    print_info "Step 2/2: Setting Celo as peer on Base contract..."

    BASE_PEER_CMD="cast send $DEST_CONTRACT_ADDRESS 'setPeer(uint32,bytes32)' ${SOURCE_EID_EFFECTIVE} $CELO_MAINNET_BYTES32 --rpc-url $RPC_URL --private-key \$PRIVATE_KEY --confirmations 1"

    if retry_command "$BASE_PEER_CMD" "Set peer on Base" 3 8; then
        print_success "✅ Peer set on Base: ${SOURCE_EID_EFFECTIVE} -> $SOURCE_CONTRACT_ADDRESS"
        BASE_PEER_SUCCESS=true
    else
        print_error "❌ Failed to set peer on Base after retries"
        BASE_PEER_SUCCESS=false
    fi

    # Verify peer configuration with retry
    if [ "$CELO_PEER_SUCCESS" = "true" ] && [ "$BASE_PEER_SUCCESS" = "true" ]; then
        print_info "Verifying peer configuration..."
        sleep 5  # Allow time for blockchain confirmation

        setup_network_config "$SOURCE_NETWORK"
        SOURCE_PEER=$(cast call $SOURCE_CONTRACT_ADDRESS "peers(uint32)" ${DESTINATION_EID} --rpc-url $RPC_URL 2>/dev/null || echo "")

        setup_network_config "$DESTINATION_NETWORK"
        DEST_PEER=$(cast call $DEST_CONTRACT_ADDRESS "peers(uint32)" ${SOURCE_EID_EFFECTIVE} --rpc-url $RPC_URL 2>/dev/null || echo "")

        if [[ "$SOURCE_PEER" == "$DEST_BYTES32" && "$DEST_PEER" == "$CELO_MAINNET_BYTES32" ]]; then
            print_success "✅ LayerZero peers verified successfully!"
        else
            print_warning "⚠️ Peer verification incomplete. Manual verification recommended:"
            echo "  Expected Celo -> Base: $DEST_BYTES32"
            echo "  Actual Celo -> Base:   $SOURCE_PEER"
            echo "  Expected Base -> Celo: $CELO_MAINNET_BYTES32"
            echo "  Actual Base -> Celo:   $DEST_PEER"
        fi
    else
        print_error "❌ Peer setup failed. Manual intervention required."
        echo
        print_warning "🔧 Manual peer setup commands:"
        echo "# Set Base as peer on Celo:"
        echo "cast send $SOURCE_CONTRACT_ADDRESS 'setPeer(uint32,bytes32)' $DESTINATION_EID $DEST_BYTES32 --rpc-url https://forno.celo.org --private-key \$PRIVATE_KEY"
        echo
        echo "# Set Celo as peer on Base:"
        echo "cast send $DEST_CONTRACT_ADDRESS 'setPeer(uint32,bytes32)' $SOURCE_EID_EFFECTIVE $CELO_MAINNET_BYTES32 --rpc-url https://mainnet.base.org --private-key \$PRIVATE_KEY"
        echo

        # Set exit code to indicate peer setup failure but continue
        PEER_SETUP_FAILED=true
        print_warning "Continuing with frontend configuration..."
    fi
fi

# Optional: Fund source contract
if [ "$AUTO_FUND_SOURCE" = "true" ]; then
    echo
    print_info "💰 Funding source contract for cross-chain gas..."
    setup_network_config "$SOURCE_NETWORK"
    
    cast send $SOURCE_CONTRACT_ADDRESS \
        --value "${FUND_AMOUNT}ether" \
        --rpc-url $RPC_URL \
        --private-key $PRIVATE_KEY \
        --confirmations 2
    
    if [ $? -eq 0 ]; then
        print_success "✅ Funded source contract with $FUND_AMOUNT CELO"
    else
        print_warning "⚠️ Failed to fund source contract"
    fi
fi

# Configure frontend automatically
echo
print_info "🎨 Configuring frontend..."

FRONTEND_ENV_FILE="../app/.env"
if [ ! -f "$FRONTEND_ENV_FILE" ]; then
    print_info "Creating frontend .env from template..."
    cp "../app/.env.example" "$FRONTEND_ENV_FILE"
fi

# Update frontend .env with deployed contract address
print_info "Updating frontend configuration with deployed contract address..."
if command -v sed >/dev/null 2>&1; then
    # Use sed to update the source contract address (preferred public var)
    sed -i.bak "s|NEXT_PUBLIC_SOURCE_CONTRACT=.*|NEXT_PUBLIC_SOURCE_CONTRACT=$SOURCE_CONTRACT_ADDRESS_CHECKSUM|g" "$FRONTEND_ENV_FILE" 2>/dev/null || { echo "NEXT_PUBLIC_SOURCE_CONTRACT=$SOURCE_CONTRACT_ADDRESS_CHECKSUM" >> "$FRONTEND_ENV_FILE"; }
    # Write chain-specific frontend variables for status panel (addresses are fine to expose)
    sed -i.bak "s|NEXT_PUBLIC_DEST_CONTRACT=.*|NEXT_PUBLIC_DEST_CONTRACT=$DEST_CONTRACT_ADDRESS|g" "$FRONTEND_ENV_FILE" 2>/dev/null || {
        echo "NEXT_PUBLIC_DEST_CONTRACT=$DEST_CONTRACT_ADDRESS" >> "$FRONTEND_ENV_FILE"
    }
    # Server-only RPC for API route (not exposed)
    sed -i.bak "s|SOURCE_RPC=.*|SOURCE_RPC=https://forno.celo.org|g" "$FRONTEND_ENV_FILE" 2>/dev/null || { echo "SOURCE_RPC=https://forno.celo.org" >> "$FRONTEND_ENV_FILE"; }
    sed -i.bak "s|DEST_RPC=.*|DEST_RPC=https://mainnet.base.org|g" "$FRONTEND_ENV_FILE" 2>/dev/null || { echo "DEST_RPC=https://mainnet.base.org" >> "$FRONTEND_ENV_FILE"; }
    sed -i.bak "s|NEXT_PUBLIC_SOURCE_EXPLORER=.*|NEXT_PUBLIC_SOURCE_EXPLORER=https://celoscan.io|g" "$FRONTEND_ENV_FILE" 2>/dev/null || {
        echo "NEXT_PUBLIC_SOURCE_EXPLORER=https://celoscan.io" >> "$FRONTEND_ENV_FILE"
    }
    sed -i.bak "s|NEXT_PUBLIC_DEST_EXPLORER=.*|NEXT_PUBLIC_DEST_EXPLORER=https://basescan.org|g" "$FRONTEND_ENV_FILE" 2>/dev/null || {
        echo "NEXT_PUBLIC_DEST_EXPLORER=https://basescan.org" >> "$FRONTEND_ENV_FILE"
    }
    sed -i.bak 's|NEXT_PUBLIC_SELF_APP_NAME=.*|NEXT_PUBLIC_SELF_APP_NAME="Self LayerZero Demo"|g' "$FRONTEND_ENV_FILE" 2>/dev/null || {
        echo 'NEXT_PUBLIC_SELF_APP_NAME="Self LayerZero Demo"' >> "$FRONTEND_ENV_FILE"
    }
    sed -i.bak 's|NEXT_PUBLIC_SELF_SCOPE=.*|NEXT_PUBLIC_SELF_SCOPE="self-workshop"|g' "$FRONTEND_ENV_FILE" 2>/dev/null || {
        echo 'NEXT_PUBLIC_SELF_SCOPE="self-workshop"' >> "$FRONTEND_ENV_FILE"
    }
    # Clean up backup files
    rm -f "$FRONTEND_ENV_FILE.bak" 2>/dev/null
    print_success "✅ Frontend configured successfully!"

    # Print a copy-paste summary so users can update manually if desired
    echo
    echo "🔧 Frontend .env updates (copy-paste if needed):"
    echo "────────────────────────────────────────────────────────────"
    echo "# Public (safe to expose)"
    echo "NEXT_PUBLIC_SELF_APP_NAME=\"Self LayerZero Demo\""
    echo "NEXT_PUBLIC_SELF_SCOPE=\"self-workshop\""
    echo "NEXT_PUBLIC_SOURCE_CONTRACT=$SOURCE_CONTRACT_ADDRESS_CHECKSUM"
    echo "NEXT_PUBLIC_DEST_CONTRACT=$DEST_CONTRACT_ADDRESS"
    echo "NEXT_PUBLIC_SOURCE_EXPLORER=https://celoscan.io"
    echo "NEXT_PUBLIC_DEST_EXPLORER=https://basescan.org"
    echo
    echo "# Server-only (do NOT prefix with NEXT_PUBLIC)"
    echo "SOURCE_RPC=https://forno.celo.org"
    echo "DEST_RPC=https://mainnet.base.org"
    echo "────────────────────────────────────────────────────────────"
    echo "Saved to: $FRONTEND_ENV_FILE"
else
    print_warning "⚠️ Could not update frontend .env automatically. Please update manually:"
    echo "NEXT_PUBLIC_SELF_ENDPOINT=$SOURCE_CONTRACT_ADDRESS_CHECKSUM"
    echo 'NEXT_PUBLIC_SELF_APP_NAME="Self LayerZero Demo"'
    echo 'NEXT_PUBLIC_SELF_SCOPE="self-workshop"'
fi

# Check contract verification status if enabled
if [ "$VERIFY_CONTRACTS" = "true" ]; then
    echo
    print_info "🔍 Checking contract verification status..."
    
    # Check Celo contract verification
    setup_network_config "$SOURCE_NETWORK"
    sleep 5  # Wait for verification to complete
    print_info "Celo contract verification: https://celoscan.io/address/$SOURCE_CONTRACT_ADDRESS_CHECKSUM#code"
    
    # Check Base Mainnet contract verification  
    setup_network_config "$DESTINATION_NETWORK"
    print_info "Base Mainnet contract verification: https://basescan.org/address/$DEST_CONTRACT_ADDRESS#code"
    
    print_success "✅ Contract verification links provided above"
fi

# Final status and exit handling
echo
if [ "$PEER_SETUP_FAILED" = "true" ]; then
    print_warning "⚠️  Deployment completed with peer setup issues!"
    echo "✅ Contracts deployed successfully"
    echo "❌ Peer setup encountered errors - automatic retry will be attempted"
    echo
    print_warning "⚠️  Next Steps:"
    echo "1. The Makefile will attempt automatic recovery"
    echo "2. If recovery fails, run: make retry-peers"
    echo "3. Or see: DEPLOYMENT_TROUBLESHOOTING.md"
    echo
    # Exit with code 2 to indicate peer setup failure (allows Makefile retry)
    exit 2
else
    print_success "🎉 Deployment and setup completed successfully!"
    print_warning "⚠️  Optional Next Steps:"
    if [ "$AUTO_FUND_SOURCE" != "true" ]; then
        echo "1. Fund source contract: cast send $SOURCE_CONTRACT_ADDRESS_CHECKSUM --value 0.01ether --rpc-url https://forno.celo.org --private-key \$PRIVATE_KEY"
    fi
    echo "2. Test verification through Self mobile app"
    echo "3. Monitor cross-chain message delivery"
    echo
    echo "📚 For detailed documentation, see docs/layerzero-integration.md"
    exit 0
fi
