// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { ProofOfHumanOApp } from "../src/ProofOfHumanOApp.sol";

/**
 * @title DeployProofOfHumanOApp
 * @notice Deployment script for ProofOfHumanOApp contract
 * @dev Deploys the Self Protocol + LayerZero integrated contract
 */
contract DeployProofOfHumanOApp is Script {
    function run() external returns (ProofOfHumanOApp) {
        // Get configuration from environment
        address identityVerificationHubV2Address = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        uint256 placeholderScope = vm.envOr("PLACEHOLDER_SCOPE", uint256(1));
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");
        address lzEndpoint = vm.envAddress("LAYERZERO_ENDPOINT_ADDRESS");
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console.log("Deploying ProofOfHumanOApp with:");
        console.log("  Hub Address:", identityVerificationHubV2Address);
        console.log("  Placeholder Scope:", placeholderScope);
        console.log("  Config ID:", vm.toString(verificationConfigId));
        console.log("  LayerZero Endpoint:", lzEndpoint);
        console.log("  Deployer:", deployer);

        vm.startBroadcast(deployer);

        ProofOfHumanOApp proofOfHumanOApp = new ProofOfHumanOApp(
            identityVerificationHubV2Address, placeholderScope, verificationConfigId, lzEndpoint, deployer
        );

        vm.stopBroadcast();

        console.log("ProofOfHumanOApp deployed at:", address(proofOfHumanOApp));

        return proofOfHumanOApp;
    }
}
