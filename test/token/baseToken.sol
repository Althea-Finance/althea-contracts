// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/token/TheaToken.sol";
import "lib/forge-std/src/Test.sol";

contract BaseToken is Test {
    TheaToken theaToken;

    address deployer = msg.sender;

    function setUp() public virtual {
        vm.prank(deployer);
        theaToken = new TheaToken(
            address(0), // layerZeroEndpoint
            address(0), // locker
            18 // sharedDecimals
        );
    }
}
