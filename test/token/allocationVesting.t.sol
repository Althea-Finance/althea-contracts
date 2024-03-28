// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/interfaces/ITheaToken.sol";
import "./baseToken.sol";

contract AllocationTest is BaseToken {
    AllocationVesting vestingContract;
    AllocationVesting.LinearVesting[] allAllocations;

    constructor() {
        // Early supporter
        uint8 DECIMALS = 18;
        allAllocations.push(
            AllocationVesting.LinearVesting(
                0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
                625000 * 10 ** DECIMALS,
                125000 * 10 ** DECIMALS,
                1718208000, //12-06-2024
                1749720258 // 12-06-2025
            )
        );
    }

    function setUp() public virtual override {
        super.setUp();
        vestingContract = new AllocationVesting(ITheaToken(address(theaToken)), allAllocations);
        vm.prank(deployer);
        theaToken.addMinter(address(vestingContract));
        vm.warp(1713173058); // 15-04-2024. Start in TGE
    }

    function testEarlySupporter_cannotClaimBeforeStartDate() public {
        AllocationVesting.LinearVesting storage earlySupporter = allAllocations[0];
        console.log("earlySupporter.recipient: %s", earlySupporter.recipient);

        // check that the wallet cannot claim before the start date
        vm.startPrank(earlySupporter.recipient);
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);

        vm.warp(1718150400); // 12-06-2024 (some hours before, still cannot claim)
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);
    }

    function testEarlySupporter_canClaimAtTGE() public {
        AllocationVesting.LinearVesting storage earlySupporter = allAllocations[0];

        vm.startPrank(earlySupporter.recipient);

        // wallet can claim allocationAtStartDate at exactly start date
        vm.warp(1718208000); // 12-06-2024
        vestingContract.claim(earlySupporter.recipient);
        assertEq(theaToken.balanceOf(earlySupporter.recipient), earlySupporter.allocationAtStartDate);

        // cannot claim anymore
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);
    }

    function testEarlySupporter_correctClaimedBalanceInFuture() public {
        AllocationVesting.LinearVesting storage earlySupporter = allAllocations[0];

        vm.startPrank(earlySupporter.recipient);
        vm.warp(1733011200); //1-12-2024

        uint256 startDate = earlySupporter.startDate;
        uint256 endDate = earlySupporter.endDate;
        uint256 allocationAtStartDate = earlySupporter.allocationAtStartDate;
        uint256 allocationAtEndDate = earlySupporter.allocationAtEndDate;

        uint256 claimed = ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) /
            (endDate - startDate);
        uint256 totalClaimed = allocationAtStartDate + claimed;
        vestingContract.claim(earlySupporter.recipient);
        assertEq(theaToken.balanceOf(earlySupporter.recipient), totalClaimed);

        // cannot claim anymore
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);

        // some days later should be able to claim more
        vm.warp(1734998400); //1-12-2024
        vestingContract.claim(earlySupporter.recipient);

        totalClaimed =
            allocationAtStartDate +
            ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) /
            (endDate - startDate);

        assertEq(theaToken.balanceOf(earlySupporter.recipient), totalClaimed);

        // At end date, should be able to claim all
        vm.warp(1749720258); //1-12-2024
        vestingContract.claim(earlySupporter.recipient);

        totalClaimed =
            allocationAtStartDate +
            ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) /
            (endDate - startDate);

        assertEq(theaToken.balanceOf(earlySupporter.recipient), totalClaimed);
        assertEq(totalClaimed, allocationAtEndDate);
        
    }
}
