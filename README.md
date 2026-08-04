> [!WARNING]
> **This boilerplate is deprecated.** It demonstrates the legacy open-source Self Pass SDK (`@selfxyz/core` + `@selfxyz/qrcode`), which must not be used for new integrations. All new integrations use **[Self Enterprise](https://docs.self.xyz/docs/self-enterprise/get-started/quickstart/)** (`@selfxyz/enterprise-sdk`): configure a flow in the [dashboard](https://dashboard.self.xyz), create a session from your backend, and redirect the user to the hosted `verificationUrl` — no QR rendering, no self-hosted verifier. Already built on this repo? Follow the [migration guide](https://docs.self.xyz/docs/self-enterprise/migration/from-self-pass-sdk/).

# Self Protocol Boilerplate Example

Learn to build privacy-preserving identity verification with [Self Protocol](https://self.xyz/) - from frontend QR codes to smart contract attestations on Celo.

> 📺 **New to Self?** Watch the [ETHGlobal Workshop](https://www.loom.com/share/8a6d116a5f66415998a496f06fefdc23) first.

## Branches
This main branch of the repo contains an example of onchain verification. If you would like to see an example with offchain/backend verification, please check out the 'backend-verification' branch.

- `main`: on chain verification
- `backend-verification`: off chain/backend verification
- `hyperlane-example`: onchain verification w/ Hyperlane bridging

## Prerequisites

- Node.js 20+
- [Self Mobile App](https://self.xyz)
- Celo wallet with testnet funds

---

## Integration Steps

### Step 1: Repository Setup

```bash
# Clone the boilerplate repository
git clone https://github.com/selfxyz/self-integration-boilerplate.git
cd workshop

# Install frontend dependencies
cd app
npm install

# Install contract dependencies
cd contracts
npm install
forge install foundry-rs/forge-std
```

### Step 2: Smart Contract Deployment

Navigate to the contracts folder and configure deployment:

```bash
# Create copy of env
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

# Deploy contract
./script/deploy-proof-of-human.sh
```

The script will:
- ✅ Build contracts with Foundry
- ✅ Deploy ProofOfHuman contract
- ✅ Verify contract on CeloScan
- ✅ Display deployment summary

### Step 3: Frontend Configuration

Configure the frontend:

Navigate to app folder
```bash
# Create copy of env
cp .env.example .env
```

Edit `.env`:
```bash
# Your deployed contract address from Step 2
# IMPORTANT: address should be lowercase
NEXT_PUBLIC_SELF_ENDPOINT=0xyour_contract_address

# App configuration
NEXT_PUBLIC_SELF_APP_NAME="Self Workshop"
NEXT_PUBLIC_SELF_SCOPE_SEED="self-workshop"
```

### Step 4: Start Development

```bash
# Start the Next.js development server
cd app
npm run dev
```

Visit `http://localhost:3000` to see your verification application!

---

## 🛠️ Detailed Configuration

### Frontend SDK Configuration

The Self SDK is configured in your React components (`app/app/page.tsx`):

```javascript
import { SelfAppBuilder, countries } from '@selfxyz/qrcode';

const app = new SelfAppBuilder({
    version: 2,                    // Always use V2
    appName: process.env.NEXT_PUBLIC_SELF_APP_NAME,
    scope: process.env.NEXT_PUBLIC_SELF_SCOPE_SEED,
    endpoint: process.env.NEXT_PUBLIC_SELF_ENDPOINT,  // Your contract address (must be lowercase)
    logoBase64: "https://i.postimg.cc/mrmVf9hm/self.png", // Logo URL or base64
    userId: userId,                // User's wallet address or identifier
    endpointType: "staging_celo",  // "staging_celo" for testnet, "celo" for mainnet
    userIdType: "hex",             // "hex" for Ethereum addresses, "uuid" for UUIDs
    userDefinedData: "Hola Buenos Aires!!!",  // Optional custom data
    
    disclosures: {
        // Verification requirements (must match your contract config)
        minimumAge: 18,
        excludedCountries: [countries.UNITED_STATES],  // Use country constants
        // ofac: true,               // Optional: OFAC compliance checking
        
        // Optional disclosures (uncomment to request):
        // name: true,
        // issuing_state: true,
        // nationality: true,
        // date_of_birth: true,
        // passport_number: true,
        // gender: true,
        // expiry_date: true,
    }
}).build();
```

### Smart Contract Configuration

Your contract extends `SelfVerificationRoot` (`contracts/src/ProofOfHuman.sol`):

```solidity
contract ProofOfHuman is SelfVerificationRoot {
    // Verification result storage
    bool public verificationSuccessful;
    address public lastUserAddress;
    bytes32 public verificationConfigId;
    
    constructor(
        address identityVerificationHubV2Address,
        string memory scopeSeed,  // Seed used to generate scope
        SelfUtils.UnformattedVerificationConfigV2 memory _verificationConfig
    ) SelfVerificationRoot(identityVerificationHubV2Address, scopeSeed) {
        // Format and set verification config
        verificationConfig = SelfUtils.formatVerificationConfigV2(_verificationConfig);
        verificationConfigId = IIdentityVerificationHubV2(identityVerificationHubV2Address)
            .setVerificationConfigV2(verificationConfig);
    }
    
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData
    ) internal override {
        // Store verification results
        verificationSuccessful = true;
        lastOutput = output;
        lastUserAddress = address(uint160(output.userIdentifier));
        
        emit VerificationCompleted(output, userData);
    }
    
    function getConfigId(
        bytes32, /* destinationChainId */
        bytes32, /* userIdentifier */
        bytes memory /* userDefinedData */
    ) public view override returns (bytes32) {
        return verificationConfigId;
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

- 📱 **Telegram Community**: [Self Protocol Builders Group](https://t.me/selfprotocolbuilder)
- 📖 **Documentation**: [docs.self.xyz](https://docs.self.xyz)
- 🎥 **Workshop Video**: [ETHGlobal Buenos Aires](https://www.loom.com/share/8a6d116a5f66415998a496f06fefdc23)

---

## 📁 Project Structure

```
self-integration-example/
├── app/                                 # Next.js frontend application
│   ├── app/
│   │   ├── page.tsx                     # Main QR code page with Self SDK integration
│   │   ├── layout.tsx                   # Root layout with metadata
│   │   ├── globals.css                  # Global styles
│   │   └── verified/
│   │       ├── page.tsx                 # Success page after verification
│   │       └── page.module.css          # Success page styles
│   ├── .env.example                     # Frontend environment template
│   ├── package.json                     # Frontend dependencies
│   ├── tailwind.config.ts               # Tailwind CSS configuration
│   └── README.md                        # Frontend documentation
│
├── contracts/                           # Foundry smart contracts
│   ├── src/
│   │   └── ProofOfHuman.sol             # Main verification contract
│   ├── script/
│   │   ├── Base.s.sol                   # Base script utilities
│   │   ├── DeployProofOfHuman.s.sol     # Foundry deployment script
│   │   └── deploy-proof-of-human.sh     # Automated deployment script
│   ├── lib/                             # Dependencies
│   │   ├── forge-std/                   # Foundry standard library
│   │   └── openzeppelin-contracts/      # OpenZeppelin contracts
│   ├── .env.example                     # Contract environment template
│   ├── foundry.toml                     # Foundry configuration
│   └── package.json                     # Contract dependencies
│
└── README.md                            # This file
```

---

## 🔗 Additional Resources

### Documentation
- [Self Protocol Docs](https://docs.self.xyz/) - Complete protocol documentation
- [Contract Integration Guide](https://docs.self.xyz/contract-integration/basic-integration) - Smart contract specifics
- [Frontend SDK Reference](https://docs.self.xyz/sdk-reference/selfappbuilder) - Frontend integration details
- [Disclosure Proofs](https://docs.self.xyz/use-self/disclosures) - Available verification options

### Self App
- [Self on iOS](https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710) - iOS App
- [Self on Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp) - Android App