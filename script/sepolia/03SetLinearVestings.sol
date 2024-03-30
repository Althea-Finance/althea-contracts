// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {TheaToken} from "src/token/TheaToken.sol";
import {AllocationVesting} from "src/token/AllocationVesting.sol";
import {RTheaAllocationVesting} from "src/token/RTheaAllocationVesting.sol";
import {RTheaToken} from "src/token/RTheaToken.sol";
import "script/sepolia/00constants.sol";

contract AltheaLinearVestingsDeployment is Script {}
