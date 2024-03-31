// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/token/RTheaAllocationVesting.sol";
import "src/token/RTheaToken.sol";
import "src/interfaces/ITheaToken.sol";
import "./baseVesting.sol";

contract rAllocationTest is AllocationVestingBaseTest {
    RTheaToken rTheaToken;
    RTheaAllocationVesting rTheaAllocationVesting;
    AllocationVesting.LinearVesting[] rTheaAllocations;

    constructor() {
        uint8 DECIMALS = 18;

        // rThea holder1
        rTheaAllocations.push(
            AllocationVesting.LinearVesting(
                makeAddr("rTheaHolder1"),
                4_000_000 * 10 ** DECIMALS,
                0,
                1733961600, //12-12-2024 (6 months after TGE)
                1797033600 // 12-12-2026 (2 years after start date)
            )
        );

        // rThea holder2
        rTheaAllocations.push(
            AllocationVesting.LinearVesting(
                makeAddr("rTheaHolder2"),
                2_000_000 * 10 ** DECIMALS,
                0,
                1733961600, //12-12-2024 (6 months after TGE)
                1797033600 // 12-12-2026 (2 years after start date)
            )
        );

        // not rThea holder but part of vesting. We do not transfer tokens to this guy
        rTheaAllocations.push(
            AllocationVesting.LinearVesting(
                makeAddr("notRTheaHolder"),
                2_000_000 * 10 ** DECIMALS,
                0,
                1733961600, //12-12-2024 (6 months after TGE)
                1797033600 // 12-12-2026 (2 years after start date)
            )
        );

        uint256 restToAllocate = 1_000_000 * 10 ** DECIMALS; // total is 9M for IDO

        rTheaAllocations.push(
            AllocationVesting.LinearVesting(
                makeAddr("restOfThePeople"),
                restToAllocate,
                0,
                1718208000, //12-06-2024 (TGE)
                1749720258 // 12-06-2025
            )
        );
    }

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);
        vestingContract = new AllocationVesting(address(theaToken));

        rTheaAllocationVesting = new RTheaAllocationVesting(address(theaToken));
        rTheaToken = new RTheaToken(address(rTheaAllocationVesting));
        rTheaAllocationVesting.setRtheaAddress(address(rTheaToken));

        rTheaToken.transfer(makeAddr("rTheaHolder1"), 4_000_000 * 10 ** 18);
        rTheaToken.transfer(makeAddr("rTheaHolder2"), 2_000_000 * 10 ** 18);
        rTheaToken.transfer(makeAddr("restOfThePeople"), 1_000_000 * 10 ** 18);

        theaToken.mintTo(address(vestingContract), 33_000_000 * 10 ** 18);
        theaToken.mintTo(address(rTheaAllocationVesting), 9_000_000 * 10 ** 18);

        vestingContract.setVestingSchedules(theaAllocations);
        rTheaAllocationVesting.setVestingSchedules(rTheaAllocations);

        vm.warp(1713173058); // 15-04-2024. Start in TGE
        vm.stopPrank();
    }

    function test_rTheaHolderCannotClaimTheaBeforeTime() public {
        // not time to claim yet
        vm.startPrank(makeAddr("rTheaHolder1"));
        rTheaToken.approve(address(rTheaAllocationVesting), 9_000_000 * 10 ** 18);
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        rTheaAllocationVesting.claim(makeAddr("rTheaHolder1"));
        vm.stopPrank();

        vm.startPrank(makeAddr("restOfThePeople"));
        rTheaToken.approve(address(rTheaAllocationVesting), 9_000_000 * 10 ** 18);
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        rTheaAllocationVesting.claim(makeAddr("restOfThePeople"));

        vm.warp(1718208000); //12-06-2024 (TGE) Rest of the people can claim but 0 tokens
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        rTheaAllocationVesting.claim(makeAddr("restOfThePeople"));
        vm.stopPrank();
    }

    function test_rTheaHolderCanClaimThea() public {
        vm.warp(1746403200); //05-05-2025

        AllocationVesting.LinearVesting memory rTheaHolder1 = rTheaAllocations[0];

        uint256 rTheaHolderShouldClaim = (rTheaHolder1.allocationAtEndDate * (block.timestamp - rTheaHolder1.startDate))
            / (rTheaHolder1.endDate - rTheaHolder1.startDate);

        uint256 theaBalanceBefore = theaToken.balanceOf(makeAddr("rTheaHolder1"));
        assertEq(theaBalanceBefore, 0);
        uint256 rTheaBalanceBefore = rTheaToken.balanceOf(makeAddr("rTheaHolder1"));
        vm.startPrank(makeAddr("rTheaHolder1"));
        rTheaToken.approve(address(rTheaAllocationVesting), rTheaHolderShouldClaim);
        rTheaAllocationVesting.claim(makeAddr("rTheaHolder1"));
        uint256 theaBalanceAfter = theaToken.balanceOf(makeAddr("rTheaHolder1"));
        uint256 rTheaBalanceAfter = rTheaToken.balanceOf(makeAddr("rTheaHolder1"));

        assertEq(rTheaBalanceBefore - rTheaBalanceAfter, rTheaHolderShouldClaim);
        assertEq(theaBalanceAfter - theaBalanceBefore, rTheaHolderShouldClaim);

        assertEq(rTheaBalanceBefore - rTheaHolderShouldClaim, rTheaToken.balanceOf(makeAddr("rTheaHolder1")));
        assertEq(rTheaHolderShouldClaim, theaBalanceAfter);

        vm.stopPrank();

        // Random wallet cannot claim
        vm.startPrank(makeAddr("randomWallet"));
        rTheaToken.approve(address(rTheaAllocationVesting), rTheaHolderShouldClaim);
        vm.expectRevert(RTheaAllocationVesting.NothingToRedeem.selector);
        rTheaAllocationVesting.claim(makeAddr("randomWallet"));

        vm.stopPrank();
    }

    function test_cannotClaimWithoutRTheaTokens() public {
        vm.startPrank(makeAddr("notRTheaHolder"));

        vm.warp(1746403300); //05-05-2025
        AllocationVesting.LinearVesting memory notRTheaHolder = rTheaAllocations[2];
        uint256 notRTheaHolderClaimable = (
            notRTheaHolder.allocationAtEndDate * (block.timestamp - notRTheaHolder.startDate)
        ) / (notRTheaHolder.endDate - notRTheaHolder.startDate);

        // Make sure the guy has the correct claimable
        assertEq(rTheaAllocationVesting.claimableNow(makeAddr("notRTheaHolder")), notRTheaHolderClaimable);

        // However, without rThea tokens, he cannot claim
        rTheaToken.approve(address(rTheaAllocationVesting), 9_000_000 * 10 ** 18);
        vm.expectRevert(RTheaAllocationVesting.NothingToRedeem.selector);
        rTheaAllocationVesting.claim(makeAddr("notRTheaHolder"));
        vm.stopPrank();

        // When he gets rThea tokens, he can claim
        vm.startPrank(deployer);
        rTheaToken.transfer(makeAddr("notRTheaHolder"), 2_000_000 * 10 ** 18);
        vm.stopPrank();

        vm.startPrank(makeAddr("notRTheaHolder"));
        uint256 rTheaBalanceBefore = rTheaToken.balanceOf(makeAddr("notRTheaHolder"));
        uint256 theaBalanceBefore = theaToken.balanceOf(makeAddr("notRTheaHolder"));

        rTheaAllocationVesting.claim(makeAddr("notRTheaHolder"));
        uint256 rTheaBalanceAfter = rTheaToken.balanceOf(makeAddr("notRTheaHolder"));
        uint256 theaBalanceAfter = theaToken.balanceOf(makeAddr("notRTheaHolder"));
        assertEq(rTheaBalanceBefore - rTheaBalanceAfter, notRTheaHolderClaimable);
        assertEq(theaBalanceAfter - theaBalanceBefore, notRTheaHolderClaimable);
        assertEq(notRTheaHolderClaimable, theaBalanceAfter);
    }

    function test_cannotClaimWithMoreRTheaTokensThanAllocation() public {
        AllocationVesting.LinearVesting memory rTheaHolder1 = rTheaAllocations[0];

        address rTheaHolder1Addr = makeAddr("rTheaHolder1");

        vm.prank(makeAddr("rTheaHolder2"));
        rTheaToken.transfer(rTheaHolder1Addr, 1_000_000 * 10 ** 18); // one more million

        vm.warp(1746403200); //05-05-2025
        // uint256 rTheaHolderShouldClaim = (rTheaHolder1.allocationAtEndDate *
        //     (block.timestamp - rTheaHolder1.startDate)) / (rTheaHolder1.endDate - rTheaHolder1.startDate);

        uint256 theaBalanceBefore = theaToken.balanceOf(rTheaHolder1Addr);
        assertEq(theaBalanceBefore, 0);

        vm.startPrank(rTheaHolder1Addr);
        rTheaToken.approve(address(rTheaAllocationVesting), rTheaHolder1.allocationAtEndDate + 1_000_000 * 10 ** 18);
        rTheaAllocationVesting.claim(rTheaHolder1Addr);

        vm.warp(1797033600); // End of vesting
        // uint256 rTheaHolderShouldClaim_newClaim = (rTheaHolder1.allocationAtEndDate *
        //     (block.timestamp - rTheaHolder1.startDate)) / (rTheaHolder1.endDate - rTheaHolder1.startDate);
        rTheaAllocationVesting.claim(rTheaHolder1Addr);
        uint256 theaBalanceAfter = theaToken.balanceOf(rTheaHolder1Addr);
        assertEq(theaBalanceAfter, rTheaHolder1.allocationAtEndDate);

        vm.warp(1798033600); // later in time
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        rTheaAllocationVesting.claim(rTheaHolder1Addr);

        assertEq(rTheaToken.balanceOf(rTheaHolder1Addr), 1_000_000 * 10 ** 18); // still has the 1MIllion
    }

    function test_cannotClaimAllClaimableDueToLackOfEnoughRThea() public {
        address notRTheaHolderAddr = makeAddr("notRTheaHolder");

        vm.startPrank(notRTheaHolderAddr);

        vm.warp(1797033600); // End of NotrThea holder vesting

        AllocationVesting.LinearVesting memory notRTheaHolder = rTheaAllocations[2];
        uint256 notRTheaHolderClaimable = (
            notRTheaHolder.allocationAtEndDate * (block.timestamp - notRTheaHolder.startDate)
        ) / (notRTheaHolder.endDate - notRTheaHolder.startDate);

        // Make sure the guy has the correct claimable
        assertEq(rTheaAllocationVesting.claimableNow(notRTheaHolderAddr), notRTheaHolderClaimable);

        // However, without rThea tokens, he cannot claim
        rTheaToken.approve(address(rTheaAllocationVesting), 2_000_000 * 10 ** 18);

        // When he gets rThea tokens, he can claim
        vm.startPrank(deployer);
        rTheaToken.transfer(notRTheaHolderAddr, 1_000_000 * 10 ** 18); // The guy onle has 1M but he needs 2 to claim.
        vm.stopPrank();

        vm.startPrank(notRTheaHolderAddr);
        rTheaAllocationVesting.claim(notRTheaHolderAddr);
        assertEq(theaToken.balanceOf(notRTheaHolderAddr), 1_000_000 * 10 ** 18);

        vm.startPrank(deployer);
        rTheaToken.transfer(notRTheaHolderAddr, 1_000_000 * 10 ** 18); // the rest
        vm.stopPrank();

        vm.startPrank(notRTheaHolderAddr);
        rTheaAllocationVesting.claim(notRTheaHolderAddr);
        assertEq(theaToken.balanceOf(notRTheaHolderAddr), 2_000_000 * 10 ** 18);
    }

    function test_partialClaimingDueToNotEnoughRThea() public {
        address notRTheaHolderAddr = makeAddr("notRTheaHolder");

        vm.warp(1746403200); // 05-05-2025

        // We give the guy a bit less than he needs
        vm.prank(deployer);
        rTheaToken.transfer(notRTheaHolderAddr, 1_800_000 * 10 ** 18);

        vm.startPrank(notRTheaHolderAddr);
        AllocationVesting.LinearVesting memory notRTheaHolder = rTheaAllocations[2];
        uint256 notRTheaHolderClaimable = (
            notRTheaHolder.allocationAtEndDate * (block.timestamp - notRTheaHolder.startDate)
        ) / (notRTheaHolder.endDate - notRTheaHolder.startDate);

        rTheaToken.approve(address(rTheaAllocationVesting), 2_000_000 * 10 ** 18);

        // But he can still claim all claimable at this point
        rTheaAllocationVesting.claim(notRTheaHolderAddr);
        assertEq(theaToken.balanceOf(notRTheaHolderAddr), notRTheaHolderClaimable);

        vm.warp(1797033600); // Now we are at the end of NotrThea holder vesting

        rTheaAllocationVesting.claim(notRTheaHolderAddr); // Although he can claim all claimable (2M), he only has 1.8M rThea
        assertEq(theaToken.balanceOf(notRTheaHolderAddr), 1_800_000 * 10 ** 18);

        vm.expectRevert(RTheaAllocationVesting.NothingToRedeem.selector);
        rTheaAllocationVesting.claim(notRTheaHolderAddr);
    }
}
