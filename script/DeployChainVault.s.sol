// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {ChainVault} from "../src/ChainVault.sol";

contract DeployChainVault is Script {
    function run() external returns (ChainVault) {
        address initialOwner = vm.envAddress("INITIAL_OWNER");

        vm.startBroadcast();

        ChainVault vault = new ChainVault(initialOwner);

        vm.stopBroadcast();

        return vault;
    }
}
