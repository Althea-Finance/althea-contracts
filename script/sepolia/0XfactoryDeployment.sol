// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {AltheaCore} from "src/core/AltheaCore.sol";
import "script/sepolia/00constants.sol";

contract AltheaCoreDeployment is Script {
    AltheaCore altheaCore;

    function setUp() public virtual {}

    function run() public {
        vm.startBroadcast();

        vm.stopBroadcast();

    }

}
