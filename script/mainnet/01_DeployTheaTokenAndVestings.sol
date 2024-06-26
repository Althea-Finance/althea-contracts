// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/Script.sol";
import {TheaToken} from "src/token/TheaToken.sol";
import {AllocationVesting} from "src/token/AllocationVesting.sol";
import {RTheaAllocationVesting} from "src/token/RTheaAllocationVesting.sol";
import {RTheaToken} from "src/token/RTheaToken.sol";
import "script/sepolia/00constants.sol";

contract AltheaTokenDeployment is Script {
    TheaToken theaToken;
    RTheaToken rTheaToken;
    AllocationVesting allocationVesting;
    RTheaAllocationVesting rTheaAllocationVesting;

    // layer zero configs for THEA token
    uint256 constant LAYER_ZERO_ENDPOINT_ID = 30151;
    address constant LAYER_ZERO_METIS_ENDPOINT = 0x1a44076050125825900e736c501f859c50fE728c; // verified
    uint8 constant LAYER_ZERO_SHARED_DECIMALS = 6; // standard shared decimals for ERC20s with 18 decimals

    // Hercules IDO configuration
    address constant HERCULES_IDO_ADDRESS = 0x4e9fFEb0272703acF643037e04FdcF86079fCb80; // validated
    uint256 constant HERCULES_IDO_THEA_ALLOCATION = 6_000_000 * 1e18;
    uint256 constant HERCULES_IDO_RTHEA_ALLOCATION = 9_000_000 * 1e18;

    // other vestings / destinations
    // includes the vestings of: Treasury, early supporters, core contributors, advisors
    uint256 constant THEA_TO_ALLOCATION_VESTING = 33_000_000 * 1e18;

    address constant VAULT_MULTISIG_ADDRESS = 0x517A3af3c8670dad0C884B7C001D9A0A40270643; // validated
    uint256 constant THEA_TO_VAULT_MULTISIG = 50_000_000 * 1e18;

    address constant TREASURY_MULTISIG_ADDRESS = 0x4f7ad18b0D9f4b493f601810a6e83FCBF02d48D3; // validated
    uint256 constant THEA_TO_TREASURY_MULTISIG = 2_000_000 * 1e18;

    function setUp() public virtual {}

    function run() public {
        vm.startBroadcast();
        deployTheaToken();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployAllocationVesting();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployRTheaAllocationVesting();
        vm.stopBroadcast();

        vm.startBroadcast();
        deployRTheaToken();
        vm.stopBroadcast();

        vm.startBroadcast();
        transferTheaAndRTheaToHerculesIDO();
        vm.stopBroadcast();

        // vm.startBroadcast();
        // mintTheaToAllocationVesting();
        // vm.stopBroadcast();

        // vm.startBroadcast();
        // mintTheaToVaultMultisig();
        // vm.stopBroadcast();

        // vm.startBroadcast();
        // mintTheaToTreasuryMultisig();
        // vm.stopBroadcast();
    }

    function deployTheaToken() internal {
        theaToken = new TheaToken(address(LAYERZERO_ENDPOINT), LAYER_ZERO_SHARED_DECIMALS);
    }

    function deployAllocationVesting() internal {
        allocationVesting = new AllocationVesting(address(theaToken));
    }

    function deployRTheaAllocationVesting() internal {
        rTheaAllocationVesting = new RTheaAllocationVesting(address(theaToken));
    }

    function deployRTheaToken() internal {
        rTheaToken = new RTheaToken(address(rTheaAllocationVesting));
        rTheaAllocationVesting.setRtheaAddress(address(rTheaToken));
    }

    function transferTheaAndRTheaToHerculesIDO() internal {
        theaToken.mintTo(HERCULES_IDO_ADDRESS, HERCULES_IDO_THEA_ALLOCATION);
        rTheaToken.transfer(HERCULES_IDO_ADDRESS, HERCULES_IDO_RTHEA_ALLOCATION);
        theaToken.mintTo(address(rTheaAllocationVesting), HERCULES_IDO_RTHEA_ALLOCATION);
    }

    // the ones below are missing

    function mintTheaToAllocationVesting() internal {
        theaToken.mintTo(address(allocationVesting), THEA_TO_ALLOCATION_VESTING);
    }

    function mintTheaToVaultMultisig() internal {
        theaToken.mintTo(VAULT_MULTISIG_ADDRESS, THEA_TO_VAULT_MULTISIG);
    }

    function mintTheaToTreasuryMultisig() internal {
        theaToken.mintTo(TREASURY_MULTISIG_ADDRESS, THEA_TO_TREASURY_MULTISIG);
    }
}
