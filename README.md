# Self Workshop

This project demonstrates integration with the [Self Protocol](https://self.xyz/) for identity verification in a Next.js application. Users can verify their identity using the Self mobile app by scanning a QR code.

## Features

- QR code generation for Self Protocol integration
- Identity verification flow
- Customizable identity verification parameters

## Prerequisites

- Node.js 20.x or higher
- NPM or Yarn
- Self Protocol App [iOS](https://apps.apple.com/us/app/self-zk/id6478563710) or [Android](https://play.google.com/store/apps/details?id=com.proofofpassportapp&pli=1) installed on your mobile device
- A public endpoint for the verification callback (can use [ngrok](https://ngrok.com/) for local development)

## Environment Setup

1. Copy the `.env.example` file to `.env.local`:
   ```bash
   cp .env.example .env.local
   ```

2. Configure the environment variables:
   - `NEXT_PUBLIC_SELF_ENDPOINT`: Set to your public endpoint (e.g., ngrok URL)
   - `NEXT_PUBLIC_SELF_APP_NAME`: Your application name (default: "Self Workshop")
   - `NEXT_PUBLIC_SELF_SCOPE`: Your application scope (default: "self-workshop")
   - `NEXT_PUBLIC_CELO_RPC_URL`: The URL of the Celo network you want to use for verification (default: "https://forno.celo.org")

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   # or
   yarn install
   ```

2. Set up a public endpoint using ngrok (if developing locally):
   ```bash
   npx ngrok http 3000
   ```
   Copy the public URL and set it as `NEXT_PUBLIC_SELF_ENDPOINT` in your `.env.local` file.

3. Run the development server:
   ```bash
   npm run dev
   # or
   yarn dev
   ```

4. Open [http://localhost:3000](http://localhost:3000) with your browser to see the application.

## How It Works

1. When users visit the homepage, a unique QR code is generated using the Self Protocol.
2. Users scan this QR code with their Self app.
3. The Self app prompts users to share their identity information.
4. After successful verification, users are redirected to the `/verified` page.

## Customization

The application can be customized by modifying the following files:

- `src/app/page.tsx`: Frontend Self Protocol integration
  - Customize the identity requirements in the `disclosures` section
  - Modify the success callback behavior

- `src/app/api/verify/route.ts`: Backend verification handler
  - Customize verification parameters
  - Modify the response handling logic

## Additional Resources

- [Self Protocol Documentation](https://docs.self.xyz/)
- [Next.js Documentation](https://nextjs.org/docs)
