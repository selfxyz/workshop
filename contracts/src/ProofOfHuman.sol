// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfVerificationRoot } from "@selfxyz/contracts/contracts/abstract/SelfVerificationRoot.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import { SelfStructs } from "@selfxyz/contracts/contracts/libraries/SelfStructs.sol";
import { SelfUtils } from "@selfxyz/contracts/contracts/libraries/SelfUtils.sol";
import { IIdentityVerificationHubV2 } from "@selfxyz/contracts/contracts/interfaces/IIdentityVerificationHubV2.sol";

/**
 * @title ProofOfHuman
 * @notice Demo implementation of SelfVerificationRoot for Proof of Human verification
 * @dev This contract provides a simple working implementation of the abstract SelfVerificationRoot
 */
contract ProofOfHuman is SelfVerificationRoot {
    // Verification result storage
    ISelfVerificationRoot.GenericDiscloseOutputV2 public lastOutput;
    bool public verificationSuccessful;
    bytes public lastUserData;
    address public lastUserAddress;

    // Verification config storage
    SelfStructs.VerificationConfigV2 public verificationConfig;
    bytes32 public verificationConfigId;

    // Events for testing
    event VerificationCompleted(ISelfVerificationRoot.GenericDiscloseOutputV2 output, bytes userData);

    /**
     * @notice Constructor for the test contract
     * @param identityVerificationHubV2Address The address of the Identity Verification Hub V2
     * @param scopeSeed The scope seed that is used to create the scope of the contract
     * @param _verificationConfig The verification configuration that will be used to process the proof in the VerificationHub
     */
    constructor(
        address identityVerificationHubV2Address,
        string memory scopeSeed, 
        SelfUtils.UnformattedVerificationConfigV2 memory _verificationConfig
    )
        SelfVerificationRoot(identityVerificationHubV2Address, scopeSeed)
    {
        verificationConfig = SelfUtils.formatVerificationConfigV2(_verificationConfig);
        verificationConfigId =
            IIdentityVerificationHubV2(identityVerificationHubV2Address).setVerificationConfigV2(verificationConfig);
    }

    /**
     * @notice Implementation of customVerificationHook from SelfVerificationRoot
     * @dev This function is called by onVerificationSuccess after hub address validation
     * @param output The verification output from the hub
     * @param userData The user data passed through verification
     */

    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output,
        bytes memory userData
    )
        internal
        override
    {
        verificationSuccessful = true;
        lastOutput = output;
        lastUserData = userData;
        lastUserAddress = address(uint160(output.userIdentifier));

        // If you wanted to get data from a disclosure, you can do it like this:
        //  issuingState = output.issuingState;
        // Make sure to have the disclosure requested in the SelfAppBuilder component in page.tsx

        emit VerificationCompleted(output, userData);
    }

    /**
     * @notice Implementation of getConfigId from SelfVerificationRoot
     * @dev Returns the verification config ID for this contract.
     *      - destinationChainId: The destination chain ID (placeholder for future crosschain use)
     *      - userIdentifier: The user identifier (passed in from the frontends userId field)
     *      - userDefinedData: The user defined data (passed in from the frontends userDefinedData field)
     * @return The verification configuration ID
     */
    function getConfigId(
        bytes32, /* destinationChainId */
        bytes32, /* userIdentifier */
        bytes memory /* userDefinedData */
    )
        public
        view
        override
        returns (bytes32)
    {
        return verificationConfigId;
    }
}
