// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {TheaToken} from "src/token/TheaToken.sol";
import "script/sepolia/00constants.sol";

contract AltheaCoreDeployment is Script {
    TheaToken theaToken;

    function setUp() public virtual {}

    function run() public {
        vm.startBroadcast();
        //        deployTheaToken();
        vm.stopBroadcast();
    }

    //    function deployTheaToken() internal {
    //        uint8 sharedDecimals = 18;
    //
    //        theaToken = new TheaToken(
    //            address(0), // Vault. Will be set later
    //            address(LAYERZERO_ENDPOINT),
    //            address(0), // TokenLocker. Will be set later
    //            sharedDecimals
    //        );
    //    }
}
