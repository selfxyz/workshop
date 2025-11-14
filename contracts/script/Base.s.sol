// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";

/// @title BaseScript
/// @notice Base script for deployment and configuration scripts
/// @dev Provides common functionality for all deployment scripts
abstract contract BaseScript is Script {
    address internal broadcaster;

    /// @notice Initialize the script with broadcaster address
    /// @dev Should be called at the beginning of run() function
    modifier broadcast() {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        broadcaster = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);
        _;
        vm.stopBroadcast();
    }
}
