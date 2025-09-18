// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ProofOfHuman } from "../src/ProofOfHuman.sol";
import { BaseScript } from "./Base.s.sol";
import { CountryCodes } from "@selfxyz/contracts/contracts/libraries/CountryCode.sol";
import { console } from "forge-std/console.sol";
import { SelfUtils } from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";

/// @title DeployProofOfHuman
/// @notice Deployment script for ProofOfHuman contract using standard deployment
contract DeployProofOfHuman is BaseScript {
    // Custom errors for deployment verification
    error DeploymentFailed();

    /// @notice Main deployment function using standard deployment
    /// @return proofOfHuman The deployed ProofOfHuman contract instance
    /// @dev Requires the following environment variables:
    ///      - IDENTITY_VERIFICATION_HUB_ADDRESS: Address of the Self Protocol verification hub
    ///      - PLACEHOLDER_SCOPE: Placeholder scope value (defaults to 1)

    function run() public broadcast returns (ProofOfHuman proofOfHuman) {
        address hubAddress = vm.envAddress("IDENTITY_VERIFICATION_HUB_ADDRESS");
        uint256 placeholderScope = vm.envOr("PLACEHOLDER_SCOPE", uint256(1)); // Use placeholder scope
        string[] memory forbiddenCountries = new string[](1);
        forbiddenCountries[0] = CountryCodes.UNITED_STATES;
        SelfUtils.UnformattedVerificationConfigV2 memory verificationConfig = SelfUtils.UnformattedVerificationConfigV2({
            olderThan: 18,
            forbiddenCountries: forbiddenCountries,
            ofacEnabled: false
        });

        // Deploy the contract using standard deployment with placeholder scope
        proofOfHuman = new ProofOfHuman(hubAddress, placeholderScope, verificationConfig);

        // Log deployment information
        console.log("ProofOfHuman deployed to:", address(proofOfHuman));
        console.log("Identity Verification Hub:", hubAddress);
        console.log("Placeholder Scope Value:", placeholderScope);

        // Verify deployment was successful
        if (address(proofOfHuman) == address(0)) revert DeploymentFailed();

        console.log("Deployment verification completed successfully!");
        console.log("Next step: Calculate actual scope using deployed address and call setScope()");
    }
}