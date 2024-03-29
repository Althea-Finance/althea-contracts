// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/token/TheaToken.sol";
import "lib/forge-std/src/Test.sol";

contract AllocationVestingBaseTest is Test {
    TheaToken theaToken;

    address deployer = makeAddr("deployer");

    function setUp() public virtual {
        vm.prank(deployer);
        theaToken = new TheaToken(
            address(0), // layerZeroEndpoint
            18 // sharedDecimals
        );
    }
}
