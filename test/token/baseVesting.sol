// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/token/TheaToken.sol";
import "src/token/RTheaToken.sol";
import "lib/forge-std/src/Test.sol";

contract AllocationVestingBaseTest is Test {
    TheaToken theaToken;
    AllocationVesting vestingContract;
    AllocationVesting.LinearVesting[] theaAllocations;

    address deployer = makeAddr("deployer");

    constructor() {
        uint8 DECIMALS = 18;

        // Early supporter, with tokens at TGE
        theaAllocations.push(
            AllocationVesting.LinearVesting(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                625000 * 10 ** DECIMALS,
                125000 * 10 ** DECIMALS,
                1718208000, //12-06-2024
                1749720258 // 12-06-2025
            )
        );

        // Core contributor, 0% at TGE and 6 months cliff
        theaAllocations.push(
            AllocationVesting.LinearVesting(
                0x23618E81e3f5a4B2a83D6431a60359aa88b7c025,
                5000000 * 10 ** DECIMALS,
                0,
                1733961600, //12-12-2024 (6 months after TGE)
                1797033600 // 12-12-2026 (2 years after start date)
            )
        );

        // Treasury, 0% at TGE linear vesting, no cliff
        theaAllocations.push(
            AllocationVesting.LinearVesting(
                0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
                2500000 * 10 ** DECIMALS,
                0,
                1718208000, //12-06-2024 (TGE)
                1781222400 // 12-06-2026 (2 years after start date)
            )
        );

        // 33M is for the Vesting contract
        uint256 restToAllocate = (33_000_000 - 625000 - 5000000 - 2500000) * 10 ** DECIMALS;

        theaAllocations.push(
            AllocationVesting.LinearVesting(
                makeAddr("restOfThePeople"),
                restToAllocate,
                0,
                1718208000, //12-06-2024 (TGE)
                1749720258 // 12-06-2025
            )
        );
    }

    function setUp() public virtual {
        vm.prank(deployer);
        theaToken = new TheaToken(
            address(0), // layerZeroEndpoint
            18 // sharedDecimals
        );
    }
}
