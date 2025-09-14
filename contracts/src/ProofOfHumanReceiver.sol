// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import { OAppOptionsType3 } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";

/**
 * @title ProofOfHumanReceiver
 * @notice Receives and processes Self Protocol verification data from Celo Mainnet via LayerZero
 * @dev This contract runs on Base Mainnet to receive verification data from Celo Mainnet
 */
contract ProofOfHumanReceiver is OApp, OAppOptionsType3 {
    // Hardcoded source: Celo Mainnet
    uint32 public constant CELO_MAINNET_EID = 30_125;

    // Cross-chain verification data structure (matches sender)
    struct CrossChainVerification {
        address userAddress;
        bytes32 verificationConfigId;
        uint256 timestamp;
        string gender;
        string nationality;
        uint256 minimumAge;
    }

    // Storage for received verifications
    mapping(address => bool) public verifiedHumans;
    mapping(address => CrossChainVerification) public verificationData;
    mapping(address => uint32) public verificationSourceChain;

    // Statistics
    uint256 public totalVerifications;
    mapping(uint32 => uint256) public verificationsPerChain;

    // Events
    event VerificationReceived(
        uint32 indexed srcEid, address indexed userAddress, bytes32 indexed verificationConfigId, uint256 timestamp
    );

    /**
     * @notice Constructor for the ProofOfHumanReceiver contract
     * @param _lzEndpoint The LayerZero endpoint address for this chain
     * @param _owner The owner address for LayerZero configurations
     */
    constructor(address _lzEndpoint, address _owner) OApp(_lzEndpoint, _owner) Ownable(_owner) {
        // No additional initialization needed
    }

    /**
     * @notice LayerZero receive function to process incoming verification data
     * @param _origin Origin information (source chain, sender address, nonce)
     * @param _guid Global unique identifier for this message
     * @param _message The encoded CrossChainVerification data
     * @param _executor Executor address that delivered the message
     * @param _extraData Additional data from the executor
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    )
        internal
        override
    {
        // Decode the cross-chain verification data
        CrossChainVerification memory verification = abi.decode(_message, (CrossChainVerification));

        // Store the verification data
        verifiedHumans[verification.userAddress] = true;
        verificationData[verification.userAddress] = verification;
        verificationSourceChain[verification.userAddress] = _origin.srcEid;

        // Update statistics
        totalVerifications++;
        verificationsPerChain[_origin.srcEid]++;

        emit VerificationReceived(
            _origin.srcEid, verification.userAddress, verification.verificationConfigId, verification.timestamp
        );
    }

    /**
     * @notice Check if a user is verified
     * @param userAddress The user address to check
     * @return verified Whether the user is verified
     * @return sourceChain The source chain EID where verification occurred
     * @return timestamp When the verification was received
     */
    function isUserVerified(address userAddress)
        external
        view
        returns (bool verified, uint32 sourceChain, uint256 timestamp)
    {
        verified = verifiedHumans[userAddress];
        if (verified) {
            sourceChain = verificationSourceChain[userAddress];
            timestamp = verificationData[userAddress].timestamp;
        }
    }

    /**
     * @notice Get detailed verification data for a user
     * @param userAddress The user address
     * @return verification The complete verification data
     */
    function getUserVerificationData(address userAddress)
        external
        view
        returns (CrossChainVerification memory verification)
    {
        require(verifiedHumans[userAddress], "User not verified");
        return verificationData[userAddress];
    }

    /**
     * @notice Get the essential verification data for a verified user
     * @param userAddress The user address
     * @return gender User's gender
     * @return nationality User's nationality
     * @return minimumAge User's minimum age
     */
    function getUserEssentialData(address userAddress)
        external
        view
        returns (string memory gender, string memory nationality, uint256 minimumAge)
    {
        require(verifiedHumans[userAddress], "User not verified");
        CrossChainVerification memory data = verificationData[userAddress];
        return (data.gender, data.nationality, data.minimumAge);
    }

    /**
     * @notice Check if verification data is still valid (not expired)
     * @param userAddress The user address
     * @param maxAge Maximum age in seconds (0 = no expiry check)
     * @return valid Whether the verification is still valid
     */
    function isVerificationValid(address userAddress, uint256 maxAge) external view returns (bool valid) {
        if (!verifiedHumans[userAddress]) return false;
        if (maxAge == 0) return true;

        return (block.timestamp - verificationData[userAddress].timestamp) <= maxAge;
    }

    /**
     * @notice Get total verification statistics
     * @return total Total number of verifications received
     */
    function getTotalVerifications() external view returns (uint256 total) {
        return totalVerifications;
    }

    /**
     * @notice Get verification count for a specific source chain
     * @param srcEid The source chain endpoint ID
     * @return count Number of verifications from that chain
     */
    function getChainVerificationCount(uint32 srcEid) external view returns (uint256 count) {
        return verificationsPerChain[srcEid];
    }

    /**
     * @notice Emergency function to remove a user's verification (owner only)
     * @param userAddress The user address to remove
     */
    function removeUserVerification(address userAddress) external onlyOwner {
        require(verifiedHumans[userAddress], "User not verified");

        // Update statistics
        uint32 srcChain = verificationSourceChain[userAddress];
        if (verificationsPerChain[srcChain] > 0) {
            verificationsPerChain[srcChain]--;
        }
        if (totalVerifications > 0) {
            totalVerifications--;
        }

        // Remove user data
        delete verifiedHumans[userAddress];
        delete verificationData[userAddress];
        delete verificationSourceChain[userAddress];
    }

    /**
     * @notice This contract only receives messages, doesn't send them
     * @dev Included for interface compliance but not used
     */
    function quoteFee(uint32, bytes memory, bytes memory, bool) external pure returns (MessagingFee memory) {
        revert("ProofOfHumanReceiver: send not supported");
    }
}
