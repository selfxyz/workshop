// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ProofOfHuman } from "../src/ProofOfHuman.sol";
import { BaseScript } from "./Base.s.sol";
import { console } from "forge-std/console.sol";

/// @title DeployProofOfHuman
/// @notice Deployment script for ProofOfHuman contract using standard deployment
contract DeployProofOfHuman is BaseScript {
    // Custom errors for deployment verification
    error DeploymentFailed();
    error VerificationConfigIdMismatch();

    /// @notice Main deployment function using standard deployment
    /// @return proofOfHuman The deployed ProofOfHuman contract instance
    /// @dev Requires the following environment variables:
    ///      - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the Self Protocol verification hub
    ///      - VERIFICATION_CONFIG_ID: The verification configuration ID (bytes32)
    ///      Optional environment variables:
    ///      - PLACEHOLDER_SCOPE: Placeholder scope value (defaults to 1)

    function run() public broadcast returns (ProofOfHuman proofOfHuman) {
        address hubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        uint256 placeholderScope = vm.envOr("PLACEHOLDER_SCOPE", uint256(1)); // Use placeholder scope
        bytes32 verificationConfigId = vm.envBytes32("VERIFICATION_CONFIG_ID");

        // Deploy the contract using standard deployment with placeholder scope
        proofOfHuman = new ProofOfHuman(hubAddress, placeholderScope, verificationConfigId);

        // Log deployment information
        console.log("ProofOfHuman deployed to:", address(proofOfHuman));
        console.log("Identity Verification Hub:", hubAddress);
        console.log("Placeholder Scope Value:", placeholderScope);
        console.log("Verification Config ID:", vm.toString(verificationConfigId));

        // Verify deployment was successful
        if (address(proofOfHuman) == address(0)) revert DeploymentFailed();
        if (proofOfHuman.verificationConfigId() != verificationConfigId) revert VerificationConfigIdMismatch();

        console.log("Deployment verification completed successfully!");
        console.log("Next step: Calculate actual scope using deployed address and call setScope()");
    }
}