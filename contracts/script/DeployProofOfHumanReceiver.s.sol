// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import { ProofOfHumanReceiver } from "../src/ProofOfHumanReceiver.sol";

/**
 * @title DeployProofOfHumanReceiver
 * @notice Deployment script for ProofOfHumanReceiver contract
 * @dev Deploys the receiver contract on destination chains
 */
contract DeployProofOfHumanReceiver is Script {
    function run() external returns (ProofOfHumanReceiver) {
        // Get configuration from environment
        address lzEndpoint = vm.envAddress("LAYERZERO_ENDPOINT_ADDRESS");
        address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

        console.log("Deploying ProofOfHumanReceiver with:");
        console.log("  LayerZero Endpoint:", lzEndpoint);
        console.log("  Deployer:", deployer);

        vm.startBroadcast(deployer);

        ProofOfHumanReceiver receiver = new ProofOfHumanReceiver(lzEndpoint, deployer);

        vm.stopBroadcast();

        console.log("ProofOfHumanReceiver deployed at:", address(receiver));

        return receiver;
    }
}
