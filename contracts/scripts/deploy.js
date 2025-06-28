const hre = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("Deploying ProofOfHuman contract...");

  const mockScope = 1; // unless you use create2 and know the address of the contract before deploying, use a mock scope and update it after deployment.
  // see https://tools.self.xyz to compute the real value of the scope will set after deployment.
  const hubAddress = process.env.IDENTITY_VERIFICATION_HUB;
  const verificationConfigId = process.env.VERIFICATION_CONFIG_ID;

  console.log("Using IdentityVerificationHub at:", hubAddress);
  console.log("Using VerificationConfigId at:", verificationConfigId);
  // Deploy the contract
  const ProofOfHuman = await hre.ethers.getContractFactory("ProofOfHuman");
  const proofOfHuman = await ProofOfHuman.deploy(hubAddress, mockScope, verificationConfigId);

  await proofOfHuman.waitForDeployment();
  const contractAddress = await proofOfHuman.getAddress();

  console.log("ProofOfHuman deployed to:", contractAddress);
  console.log("Network:", hre.network.name);

  // Wait for a few block confirmations
  console.log("Waiting for block confirmations...");
  await proofOfHuman.deploymentTransaction().wait(5);

  // Verify the contract on Celoscan
  if (hre.network.name === "alfajores" && process.env.CELOSCAN_API_KEY) {
    console.log("Verifying contract on Celoscan...");
    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [hubAddress, mockScope, verificationConfigId],
        network: "alfajores"
      });
      console.log("Contract verified successfully!");
    } catch (error) {
      console.log("Verification failed:", error.message);
      if (error.message.includes("already verified")) {
        console.log("Contract was already verified.");
      }
    }
  } else if (!process.env.CELOSCAN_API_KEY) {
    console.log("Skipping verification: CELOSCAN_API_KEY not found in environment");
  }

  // Save deployment info
  const fs = require("fs");
  const deploymentInfo = {
    network: hre.network.name,
    contractAddress: contractAddress,
    hubAddress: hubAddress,
    deployedAt: new Date().toISOString(),
    deployer: (await hre.ethers.provider.getSigner()).address
  };

  fs.writeFileSync(
    "./deployments/latest.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\nDeployment complete!");
  console.log("Contract address:", contractAddress);
  console.log("\nNext steps:");
  console.log("1. Update NEXT_PUBLIC_SELF_ENDPOINT in app/.env");
  console.log("2. Go to https://tools.self.xyz, generate the scope and update it in your contract");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });