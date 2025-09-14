// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Test, console } from "forge-std/Test.sol";
import { ProofOfHumanOApp } from "../src/ProofOfHumanOApp.sol";
import { ProofOfHumanReceiver } from "../src/ProofOfHumanReceiver.sol";
import { ISelfVerificationRoot } from "@selfxyz/contracts/contracts/interfaces/ISelfVerificationRoot.sol";

contract ProofOfHumanOAppForkTest is Test {
    // Celo Mainnet
    address constant CELO_HUB = 0xe57F4773bd9c9d8b6Cd70431117d353298B9f5BF; // IdentityVerificationHubV2
    address constant CELO_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 constant CELO_EID = 30_125;

    // Base Mainnet
    address constant BASE_LZ_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c;
    uint32 constant BASE_EID = 30_184;

    // RPC URLs
    string constant CELO_RPC = "https://forno.celo.org";
    string constant BASE_RPC = "https://mainnet.base.org";

    // Test params
    bytes32 constant CONFIG_ID = bytes32(uint256(0x1234));
    uint256 constant SCOPE = 1;
    uint256 constant NULLIFIER = 54_321;

    // Actors
    address owner = address(0xA11CE);
    address user = address(0xBEE5);

    // Fork ids
    uint256 celoFork;
    uint256 baseFork;

    // Deployed contracts
    ProofOfHumanOApp source;
    ProofOfHumanReceiver dest;

    function setUp() public {
        // Create forks
        celoFork = vm.createFork(CELO_RPC);
        baseFork = vm.createFork(BASE_RPC);

        // Deploy destination (Base)
        vm.selectFork(baseFork);
        vm.startPrank(owner);
        dest = new ProofOfHumanReceiver(BASE_LZ_ENDPOINT, owner);
        vm.stopPrank();

        // Deploy source (Celo)
        vm.selectFork(celoFork);
        vm.startPrank(owner);
        source = new ProofOfHumanOApp(CELO_HUB, SCOPE, CONFIG_ID, CELO_LZ_ENDPOINT, owner);
        vm.stopPrank();

        // Configure peers
        vm.selectFork(celoFork);
        vm.prank(owner);
        source.setPeer(BASE_EID, bytes32(uint256(uint160(address(dest)))));

        vm.selectFork(baseFork);
        vm.prank(owner);
        dest.setPeer(CELO_EID, bytes32(uint256(uint160(address(source)))));

        // Fund source contract on Celo to pay LZ native fees
        vm.selectFork(celoFork);
        // Provide ample balance to cover DVN + executor fees on mainnet
        vm.deal(address(source), 1 ether);

        vm.label(address(source), "Source");
        vm.label(address(dest), "Dest");
        vm.label(CELO_HUB, "Celo Hub");
        vm.label(CELO_LZ_ENDPOINT, "Celo LZ Endpoint");
        vm.label(BASE_LZ_ENDPOINT, "Base LZ Endpoint");
        vm.label(owner, "Owner");
        vm.label(user, "User");
    }

    function test_SendOnVerificationSuccess_EmitsEventAndDoesNotRevert() public {
        vm.selectFork(celoFork);

        // Build a minimal GenericDiscloseOutputV2
        ISelfVerificationRoot.GenericDiscloseOutputV2 memory output = ISelfVerificationRoot.GenericDiscloseOutputV2({
            attestationId: bytes32(0),
            userIdentifier: uint256(uint160(user)),
            nullifier: NULLIFIER,
            forbiddenCountriesListPacked: [uint256(0), uint256(0), uint256(0), uint256(0)],
            issuingState: "US",
            name: _mockName(),
            idNumber: "123456789",
            nationality: "US",
            dateOfBirth: "1990-01-01",
            gender: "M",
            expiryDate: "2030-12-31",
            olderThan: 18,
            ofac: [false, false, false]
        });

        // Create expected simplified verification data
        ProofOfHumanOApp.CrossChainVerification memory expectedData = ProofOfHumanOApp.CrossChainVerification({
            userAddress: user,
            verificationConfigId: CONFIG_ID,
            timestamp: block.timestamp,
            gender: "M",
            nationality: "US",
            minimumAge: 18
        });

        // Expect our OApp event (indexed topics only), from the OApp emitter
        vm.expectEmit(true, true, true, false, address(source));
        emit ProofOfHumanOApp.VerificationSentCrossChain(BASE_EID, user, CONFIG_ID, expectedData);

        // Simulate hub callback, triggers customVerificationHook which sends cross-chain
        vm.prank(CELO_HUB);
        source.onVerificationSuccess(abi.encode(output), abi.encode(user));

        // Sanity: user marked verified on source
        assertTrue(source.verifiedHumans(user));
        assertTrue(source.usedNullifier(NULLIFIER));

        console.log("Contract balance after verification:", address(source).balance);
    }

    function _mockName() internal pure returns (string[] memory arr) {
        arr = new string[](1);
        arr[0] = "Test User";
    }
}
