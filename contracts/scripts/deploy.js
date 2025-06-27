const hre = require("hardhat");
require("dotenv").config();

async function main() {
  console.log("Deploying ProofOfHuman contract...");
  
  // Get the hub address from environment
  const hubAddress = process.env.IDENTITY_VERIFICATION_HUB;
  console.log("Using IdentityVerificationHub at:", hubAddress);
  
  // Deploy the contract
  const ProofOfHuman = await hre.ethers.getContractFactory("ProofOfHuman");
  const proofOfHuman = await ProofOfHuman.deploy(hubAddress);
  
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
        constructorArguments: [hubAddress],
      });
      console.log("Contract verified successfully!");
    } catch (error) {
      console.log("Error verifying contract:", error.message);
    }
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
  console.log("1. Update NEXT_PUBLIC_PROOF_OF_HUMAN_CONTRACT in frontend/.env.local");
  console.log("2. Update the frontend to use this contract address");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });