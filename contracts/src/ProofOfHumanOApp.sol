// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { SelfVerificationRoot } from "@selfxyz/contracts/contracts/abstract/SelfVerificationRoot.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ProofOfHumanOApp
 * @notice Self Protocol verification contract with LayerZero cross-chain messaging
 * @dev Extends ProofOfHuman to send verification results to other chains via LayerZero
 */
contract ProofOfHumanOApp is SelfVerificationRoot, OApp, OAppOptionsType3 {
    using OptionsBuilder for bytes;
    // Storage for verification tracking

    mapping(uint256 => bool) public usedNullifier;
    mapping(address => bool) public verifiedHumans;
    mapping(address => CrossChainVerification) public verificationData;
    bytes32 public verificationConfigId;

    // Destination chain eid (Base Mainnet)
    uint32 public constant DESTINATION_EID = 30_184;

    // LayerZero message types
    uint16 public constant SEND = 1;

    // Cross-chain verification data structure
    struct CrossChainVerification {
        address userAddress;
        bytes32 verificationConfigId;
        uint256 timestamp;
        string gender;
        string nationality;
        uint256 minimumAge;
    }

    event VerificationSentCrossChain(
        uint32 indexed dstEid,
        address indexed userAddress,
        bytes32 indexed verificationConfigId,
        CrossChainVerification data
    );

    /**
     * @notice Constructor for the ProofOfHumanOApp contract
     * @param _identityVerificationHubV2Address The address of the Identity Verification Hub V2
     * @param _scope The scope for verification
     * @param _verificationConfigId The verification configuration ID
     * @param _lzEndpoint The LayerZero endpoint address
     * @param _owner The owner address for both Self Protocol and LayerZero configurations
     */
    constructor(
        address _identityVerificationHubV2Address,
        uint256 _scope,
        bytes32 _verificationConfigId,
        address _lzEndpoint,
        address _owner
    )
        SelfVerificationRoot(_identityVerificationHubV2Address, _scope)
        OApp(_lzEndpoint, _owner)
        Ownable(_owner)
    {
        verificationConfigId = _verificationConfigId;
    }

    /**
     * @notice Implementation of customVerificationHook with cross-chain messaging
     * @dev Called after successful verification, stores data and automatically sends to Base Mainnet
     * @param _output The verification output from the hub
     * @param _userData The user data (expected to be the user address)
     */
    function customVerificationHook(
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory _output,
        bytes memory _userData
    )
        internal
        override
    {
        require(!usedNullifier[_output.nullifier], "Nullifier already used");

        address userAddress = address(uint160(_output.userIdentifier));

        // Store simplified verification data locally
        usedNullifier[_output.nullifier] = true;
        verifiedHumans[userAddress] = true;

        // Extract only essential data
        CrossChainVerification memory crossChainData = CrossChainVerification({
            userAddress: userAddress,
            verificationConfigId: verificationConfigId,
            timestamp: block.timestamp,
            gender: _output.gender,
            nationality: _output.nationality,
            minimumAge: _output.olderThan
        });

        verificationData[userAddress] = crossChainData;

        // Automatically send verification to destination chain
        _sendVerificationToBase(userAddress, crossChainData);
    }

    /**
     * @notice Send verification data to destination chain
     * @param _userAddress The user address
     * @param _crossChainData The verification data to send
     */
    function _sendVerificationToBase(address _userAddress, CrossChainVerification memory _crossChainData) internal {
        bytes memory message = abi.encode(_crossChainData);
        // Use OptionsBuilder to set 500,000 gas on destination lzReceive
        bytes memory options = this.combineOptions(
            DESTINATION_EID, SEND, OptionsBuilder.newOptions().addExecutorLzReceiveOption(500_000, 0)
        );

        // Get fee quote for destination
        MessagingFee memory fee = _quote(DESTINATION_EID, message, options, false);

        _lzSend(DESTINATION_EID, message, options, fee, payable(address(this)));

        emit VerificationSentCrossChain(DESTINATION_EID, _userAddress, verificationConfigId, _crossChainData);
    }

    /**
     * @notice Manual function to send verification to destination chain (for already verified users)
     * @param userAddress The address of the verified user
     */
    function sendVerificationToBase(address userAddress) external payable {
        require(verifiedHumans[userAddress], "User not verified");

        // Get existing verification data
        CrossChainVerification memory crossChainData = verificationData[userAddress];

        bytes memory message = abi.encode(crossChainData);

        // Use OptionsBuilder to set 500,000 gas on destination lzReceive
        bytes memory options = this.combineOptions(
            DESTINATION_EID, SEND, OptionsBuilder.newOptions().addExecutorLzReceiveOption(500_000, 0)
        );

        MessagingFee memory fee = _quote(DESTINATION_EID, message, options, false);

        // Contract will pay; allow optional msg.value (excess refunded by endpoint)
        _lzSend(DESTINATION_EID, message, options, fee, payable(msg.sender));

        emit VerificationSentCrossChain(DESTINATION_EID, userAddress, verificationConfigId, crossChainData);
    }

    /**
     * @notice Quote the cost of sending verification data to destination chain
     * @param userAddress The address of the user to send verification for
     * @return fee Messaging fee for sending
     */
    function quoteVerificationToBase(address userAddress) external view returns (MessagingFee memory fee) {
        require(verifiedHumans[userAddress], "User not verified");

        // Use existing verification data
        CrossChainVerification memory crossChainData = verificationData[userAddress];

        bytes memory message = abi.encode(crossChainData);
        // 500,000 gas on destination lzReceive
        bytes memory opts = OptionsBuilder.newOptions().addExecutorLzReceiveOption(500_000, 0);
        fee = _quote(DESTINATION_EID, message, opts, false);
    }

    /**
     * @notice Expose the internal _setScope function for testing
     * @param newScope The new scope value to set
     */
    function setScope(uint256 newScope) external onlyOwner {
        _setScope(newScope);
    }

    /**
     * @notice Update verification config ID
     * @param configId New verification config ID
     */
    function setConfigId(bytes32 configId) external onlyOwner {
        verificationConfigId = configId;
    }

    /**
     * @notice Get verification config ID
     */
    function getConfigId(bytes32, bytes32, bytes memory) public view override returns (bytes32) {
        return verificationConfigId;
    }

    /**
     * @notice Withdraw contract balance (owner only)
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Pay LayerZero native fee from contract balance by default, or accept msg.value if provided.
     *      This enables _lzSend to work when called from hooks/relayers that do not send value.
     */
    function _payNative(uint256 _nativeFee) internal override returns (uint256) {
        if (msg.value == 0) {
            require(address(this).balance >= _nativeFee, "Insufficient contract balance");
            return _nativeFee; // deduct from contract balance via endpoint.send
        } else {
            require(msg.value >= _nativeFee, "Insufficient msg.value");
            return msg.value; // endpoint refunds any excess to refund address
        }
    }

    /**
     * @notice Allow contract to receive ETH for gas payments
     */
    receive() external payable { }

    /**
     * @notice LayerZero receive function (not used in this implementation)
     * @dev This contract only sends messages, doesn't receive them
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata, address, bytes calldata) internal pure override {
        revert("ProofOfHumanOApp: receive not implemented");
    }
}
