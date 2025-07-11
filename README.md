# Self Protocol Workshop - Identity Verification with Zero-Knowledge Proofs

A comprehensive workshop project demonstrating how to build a decentralized identity verification system using [Self Protocol](https://self.xyz/). This project showcases the integration of zero-knowledge proof-based passport verification in a Next.js application with optional smart contract integration on the Celo blockchain.

## 🎯 Workshop Overview

This workshop teaches developers how to:
- Build privacy-preserving identity verification flows
- Integrate Self Protocol's SDK for passport-based verification
- Create user-friendly QR code-based authentication
- Handle zero-knowledge proofs for age, nationality, and OFAC compliance checks
- (Optional) Deploy smart contracts for on-chain verification attestations

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  Next.js App    │────▶│  Self Protocol  │────▶│  Smart Contract │
│  (Frontend)     │     │  Backend API    │     │  (Optional)     │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                        │                        │
        ▼                        ▼                        ▼
    QR Code              ZK Proof Verification    On-chain Attestation
   Generation             & Validation            (Celo Blockchain)
```

## 🚀 Features

### Core Features
- **QR Code Authentication**: Dynamic QR code generation for seamless mobile verification
- **Zero-Knowledge Proofs**: Privacy-preserving identity verification without exposing personal data
- **Configurable Requirements**: Set custom age limits, excluded countries, and compliance checks
- **Real-time Verification**: WebSocket-based updates for instant verification feedback
- **Mock Passport Support**: Test environment support for development without real passports

### Technical Highlights
- **Next.js 14** with App Router for modern React development
- **TypeScript** for type-safe code
- **Self Protocol SDK** (`@selfxyz/core` and `@selfxyz/qrcode`) integration
- **Responsive Design** with Tailwind CSS
- **Error Handling** with detailed validation feedback
- **Environment-based Configuration** for easy deployment

## 📋 Prerequisites

### Required
- **Node.js 20.x** or higher (specified in `package.json` engines)
- **npm** or **yarn** package manager
- **Self Mobile App** installed on your phone:
  - [iOS App Store](https://apps.apple.com/us/app/self-zk/id6478563710)
  - [Google Play Store](https://play.google.com/store/apps/details?id=com.proofofpassportapp)

### For Local Development
- **ngrok** or similar tunneling service (for public endpoint exposure)
- **Git** for version control

### For Smart Contract Deployment (Optional)
- **Celo wallet** with test funds (for Alfajores testnet)
- **Hardhat** or similar deployment tool
- **Celoscan API key** for contract verification

## 🛠️ Installation & Setup

### 1. Clone the Repository
```bash
git clone <repository-url>
cd self-workshop
```

### 2. Install Dependencies
```bash
npm install
# or
yarn install
```

### 3. Environment Configuration

#### Create Environment File
```bash
cp .env.example .env.local
```

#### Configure Required Variables
Edit `.env.local` with your settings:

```env
# REQUIRED: Public endpoint for verification callback (cannot be localhost)
# For local dev, use ngrok: npx ngrok http 3000
NEXT_PUBLIC_SELF_ENDPOINT=https://your-public-url.ngrok-free.app

# Application Identity
NEXT_PUBLIC_SELF_APP_NAME="Self Workshop"
NEXT_PUBLIC_SELF_SCOPE="self-workshop"

# Blockchain Configuration
NEXT_PUBLIC_CELO_RPC_URL="https://forno.celo.org"

# Development Settings
NEXT_PUBLIC_SELF_ENABLE_MOCK_PASSPORT="true"  # Set to "false" for production
```

### 4. Set Up Public Endpoint (Local Development)

Since Self Protocol requires a public endpoint for callbacks, use ngrok:

```bash
# Install ngrok globally (if not already installed)
npm install -g ngrok

# Expose your local server
npx ngrok http 3000

# Copy the HTTPS URL (e.g., https://abc123.ngrok-free.app)
# Update NEXT_PUBLIC_SELF_ENDPOINT in .env.local
```

### 5. Start the Development Server
```bash
npm run dev
# or
yarn dev
```

Visit `http://localhost:3000` to see the application.

## 🔧 How It Works

### 1. QR Code Generation
When a user visits the homepage, the app:
- Generates a unique session ID using UUID v4
- Creates a Self Protocol verification request with specified requirements
- Renders a QR code containing the verification link

### 2. Mobile Verification Flow
Users scan the QR code with the Self app, which:
- Reads passport data using NFC
- Generates zero-knowledge proofs for requested attributes
- Sends proofs to your verification endpoint

### 3. Backend Verification
The API endpoint (`/api/verify`) handles:
- Proof validation using Self Protocol's verifier
- Attribute checking (age, nationality, OFAC status)
- Response formatting with detailed error messages

### 4. Success State
Upon successful verification:
- Frontend receives success callback
- User is redirected to `/verified` page
- Optional: Smart contract records verification on-chain

## 📝 Configuration Options

### Verification Requirements (in `src/app/page.tsx`)

```typescript
const minimumAge = 30;                           // Minimum age requirement
const excludedCountries = [countries.FRANCE];    // Excluded nationalities
const requireName = true;                        // Request name disclosure
const checkOFAC = true;                         // Enable OFAC compliance check
```

### Supported Verification Attributes
- **Age Verification**: Prove age above threshold without revealing exact age
- **Nationality**: Verify country of citizenship
- **OFAC Compliance**: Check against sanctions lists
- **Name Disclosure**: Optional name revelation
- **Passport Validity**: Ensure non-expired passport

## 🏃‍♂️ Workshop Exercises

### Exercise 1: Basic Integration
1. Set up the development environment
2. Configure environment variables
3. Run the application and test with mock passport

### Exercise 2: Customize Requirements
1. Modify age requirements
2. Add/remove excluded countries
3. Toggle OFAC checking
4. Test different configurations


### Exercise 3: Smart Contract Integration
1. Deploy the ProofOfHuman contract
2. Connect frontend to contract
3. Store verification attestations on-chain
4. Query verification status from blockchain

## 🚢 Deployment

### Vercel Deployment (Recommended)
1. Push code to GitHub
2. Connect repository to Vercel
3. Set environment variables in Vercel dashboard
4. Deploy

### Manual Deployment
```bash
# Build the application
npm run build

# Start production server
npm start
```

### Environment Variables for Production
- Set `NEXT_PUBLIC_SELF_ENABLE_MOCK_PASSPORT="false"`
- Use production endpoints
- Configure proper CORS and security headers

## 🐛 Troubleshooting

### Common Issues

#### "Verification failed" Error
- Check that `NEXT_PUBLIC_SELF_ENDPOINT` is publicly accessible
- Ensure environment variables are properly set
- Verify the Self app is up to date

#### QR Code Not Scanning
- Ensure good lighting conditions
- Try refreshing the page for a new QR code
- Check that the Self app has camera permissions

#### Mock Passport Not Working
- Confirm `NEXT_PUBLIC_SELF_ENABLE_MOCK_PASSPORT="true"`
- Restart the development server after changing env variables
- Clear browser cache

#### CORS Issues
- Ensure your public endpoint supports CORS
- Check ngrok configuration for local development
- Add appropriate headers in production

## 📚 Project Structure

```
self-workshop/
├── src/
│   ├── app/
│   │   ├── api/
│   │   │   └── verify/
│   │   │       └── route.ts      # Verification endpoint
│   │   ├── verified/
│   │   │   ├── page.tsx          # Success page
│   │   │   └── page.module.css   # Success page styles
│   │   ├── page.tsx              # Main QR code page
│   │   ├── layout.tsx            # Root layout
│   │   └── globals.css           # Global styles
│   └── ...
├── contracts/                     # Smart contract artifacts
│   ├── artifacts/                # Compiled contracts
│   └── .env                      # Contract deployment config
├── public/                       # Static assets
├── .env.example                  # Environment template
├── package.json                  # Dependencies
└── README.md                     # This file
```

## 🔗 Additional Resources

### Documentation
- [Self Protocol Documentation](https://docs.self.xyz/)
- [Self Protocol GitHub](https://github.com/proofofpassport)
- [Next.js Documentation](https://nextjs.org/docs)
- [Celo Documentation](https://docs.celo.org/)

### Community & Support
- [Workshop Issues](https://github.com/your-repo/issues)

### Related Projects
- [Proof of Passport](https://proofofpassport.com/)
- [OpenPassport](https://openpassport.app/)

## 📄 License

This project is for educational purposes. Please refer to the repository license for usage terms.

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request
