# Self Protocol Workshop

Learn to build privacy-preserving identity verification with [Self Protocol](https://self.xyz/) - from frontend QR codes to smart contract attestations on Celo.

> 📺 **New to Self?** Watch the [ETHGlobal Workshop](https://www.youtube.com/live/0Jg1o9BFUBs?si=4g0okIn91QMIzew-) first.

## Prerequisites

- Node.js 20+
- [Self Mobile App](https://self.xyz/download) (iOS/Android)
- Celo wallet with testnet funds

---

## Workshop Steps

### Step 1: Repository Setup

```bash
# Clone the workshop repository
git clone <repository-url>
cd workshop

# Install frontend dependencies
cd app
npm install
cd ..

# Install contract dependencies
cd contracts
npm install        
forge install foundry-rs/forge-std
```

### Step 2: Smart Contract Deployment

Navigate to the contracts folder and configure deployment:

```bash
# Copy and configure environment
cp .env.example .env
```

Edit `.env` with your values:
```bash
# Your private key (with 0x prefix)
PRIVATE_KEY=0xyour_private_key_here

# Network selection
NETWORK=celo-sepolia

# Scope calculation
SCOPE_SEED="self-workshop"
```

Deploy the contract:
```bash
# Make script executable
chmod +x script/deploy-proof-of-human.sh

# Deploy contract (handles everything automatically)
./script/deploy-proof-of-human.sh
```

> **⚠️ Troubleshooting Celo Sepolia**: If you encounter a `Chain 11142220 not supported` error when using `celo-sepolia`, update Foundry to version 0.3.0:
> ```bash
> foundryup --install 0.3.0
> ```

The script will:
- ✅ Build contracts with Foundry
- ✅ Deploy ProofOfHuman contract
- ✅ Verify contract on CeloScan
- ✅ Display deployment summary

### Step 4: Frontend Configuration

Configure the frontend:

```bash
cd ../app  # Go to app directory
cp .env.example .env
```

Edit `.env`:
```bash
# Your deployed contract address from Step 3
# notice that the address should be lowercase
NEXT_PUBLIC_SELF_ENDPOINT=0xyour_contract_address



# App configuration
NEXT_PUBLIC_SELF_APP_NAME="Self Workshop"
NEXT_PUBLIC_SELF_SCOPE="self-workshop"
```

### Step 4: Start Development

```bash
# Navigate to app directory and start the Next.js development server
cd app
npm run dev
```

Visit `http://localhost:3000` to see your verification application!

---

## 🛠️ Detailed Configuration

### Frontend SDK Configuration

The Self SDK is configured in your React components:

```javascript
import { SelfAppBuilder } from '@selfxyz/core';

const selfApp = new SelfAppBuilder({
    // Contract integration settings
    endpoint: process.env.NEXT_PUBLIC_CONTRACT_ADDRESS,
    endpointType: "staging_celo",  // Use "celo" for mainnet
    userIdType: "hex",             // For wallet addresses
    version: 2,                    // Always use V2
    
    // App details
    appName: "Self Workshop",
    scope: "self-workshop",
    userId: userWalletAddress,

    disclosures: {
        // Verification requirements (must match your contract config)
        minimumAge: 18,
        excludedCountries: ["USA"],  // 3-letter country codes
        ofac: false,                 // OFAC compliance checking
        // disclosures
        name: true,                  // Request name disclosure
        nationality: true,           // Request nationality disclosure
        gender: true,                // Request gender disclosure
        date_of_birth: true,         // Request date of birth disclosure
        passport_number: true,       // Request passport number disclosure
        expiry_date: true,           // Request expiry date disclosure
    }
}).build();
```

### Smart Contract Configuration

Your contract extends `SelfVerificationRoot`:

```solidity
contract ProofOfHuman is SelfVerificationRoot {
    mapping(address => bool) public verifiedHumans;
    bytes32 public verificationConfigId;
    
    constructor(
        address _hubAddress,
        uint256 _scope,
        bytes32 _verificationConfigId
    ) SelfVerificationRoot(_hubAddress, _scope) {
        verificationConfigId = _verificationConfigId;
    }
    
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData
    ) internal override {
        // Mark user as verified
        address userAddress = address(uint160(output.userIdentifier));
        verifiedHumans[userAddress] = true;
        
        emit VerificationCompleted(output, userData);
    }
}
```

### Network Configuration

#### Celo Sepolia (Testnet)
- **Hub Address**: `0x16ECBA51e18a4a7e61fdC417f0d47AFEeDfbed74`
- **RPC**: `https://forno.celo-sepolia.celo-testnet.org`
- **Explorer**: `https://celo-sepolia.blockscout.com/`
- **Supports**: Mock passports for testing

#### Celo Mainnet
- **Hub Address**: `0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF`
- **RPC**: `https://forno.celo.org`
- **Explorer**: `https://celoscan.io`
- **Supports**: Real passport verification

---

### Getting Help

- 📱 **Telegram Community**: [Self Protocol Support](https://t.me/selfprotocol)
- 📖 **Documentation**: [docs.self.xyz](https://docs.self.xyz)
- 🎥 **Workshop Video**: [ETHGlobal Cannes](https://www.youtube.com/live/0Jg1o9BFUBs)
- 💬 **GitHub Issues**: Report workshop-specific issues

---

## 📁 Project Structure

```
workshop/
├── app/
│   ├── app/
│   │   ├── verified/page.tsx        # Success page
│   │   ├── page.tsx                 # Main QR code page
│   │   └── layout.tsx               # Root layout
│   └── components/                  # React components
├── contracts/
│   ├── src/ProofOfHuman.sol         # Main contract
│   ├── script/
│   │   ├── Deploy*.s.sol            # Deployment scripts
│   │   └── deploy-proof-of-human.sh # Deployment automation
│   ├── .env.example                 # Contract environment template
│   ├── foundry.toml                 # Foundry configuration
│   └── DEPLOYMENT.md                # Detailed deployment guide
├── public/                          # Static assets
├── .env.example                     # Frontend environment template
└── README.md                        # This file
```

---

## 🔗 Additional Resources

### Documentation
- [Self Protocol Docs](https://docs.self.xyz/) - Complete protocol documentation
- [Contract Integration Guide](https://docs.self.xyz/contract-integration/basic-integration) - Smart contract specifics
- [Frontend SDK Reference](https://docs.self.xyz/sdk-reference/selfappbuilder) - Frontend integration details
- [Verification Disclosures](https://docs.self.xyz/use-self/disclosures) - Available verification options

### Tools & Utilities
- [tools.self.xyz](https://tools.self.xyz) - Configuration and deployment tools
- [Self Mobile Apps](https://self.xyz/download) - iOS and Android apps
- [Celo Documentation](https://docs.celo.org/) - Blockchain platform docs
- [Foundry Documentation](https://book.getfoundry.sh/) - Smart contract framework

### Community & Support
- [Self Protocol Telegram](https://t.me/selfprotocol) - Community support
- [GitHub Repository](https://github.com/selfxyz) - Source code and issues
- [ETHGlobal Workshop](https://www.youtube.com/live/0Jg1o9BFUBs) - Video tutorial