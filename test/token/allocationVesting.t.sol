// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "script/generatedAllocations.sol";
import "src/token/AllocationVesting.sol";
import "src/interfaces/ITheaToken.sol";
import "./baseVesting.sol";

contract AllocationTest is AllocationVestingBaseTest {
    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);
        vestingContract = new AllocationVesting(address(theaToken));

        theaToken.mintTo(address(vestingContract), 33_000_000 * 10 ** 18);

        vestingContract.setVestingSchedules(theaAllocations);
        vm.warp(1713173058); // 15-04-2024. Start in TGE
        vm.stopPrank();
    }

    function testEarlySupporter_cannotClaimBeforeStartDate() public {
        AllocationVesting.LinearVesting storage earlySupporter = theaAllocations[0];
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
        AllocationVesting.LinearVesting storage earlySupporter = theaAllocations[0];

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
        AllocationVesting.LinearVesting storage earlySupporter = theaAllocations[0];

        vm.startPrank(earlySupporter.recipient);
        vm.warp(1733011200); //1-12-2024

        uint256 startDate = earlySupporter.startDate;
        uint256 endDate = earlySupporter.endDate;
        uint256 allocationAtStartDate = earlySupporter.allocationAtStartDate;
        uint256 allocationAtEndDate = earlySupporter.allocationAtEndDate;

        uint256 claimed =
            ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) / (endDate - startDate);
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

        totalClaimed = allocationAtStartDate
            + ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) / (endDate - startDate);

        assertEq(theaToken.balanceOf(earlySupporter.recipient), totalClaimed);

        // At end date, should be able to claim all
        vm.warp(1749720258); //12-6-2025
        vestingContract.claim(earlySupporter.recipient);

        totalClaimed = allocationAtStartDate
            + ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) / (endDate - startDate);

        assertEq(theaToken.balanceOf(earlySupporter.recipient), totalClaimed);
        assertEq(totalClaimed, allocationAtEndDate);

        // next day, nothing to claim
        vm.warp(1749772800); //13-06-2025
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(earlySupporter.recipient);
    }

    function testCoreContributor() public {
        AllocationVesting.LinearVesting storage coreContributor = theaAllocations[1];

        vm.startPrank(coreContributor.recipient);

        vm.warp(1733875200); //11-12-2024, nothing to claim yet
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(coreContributor.recipient);

        vm.warp(1733961600); //12-12-2024
        // 0% at TGE, should not be able to claim
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(coreContributor.recipient);

        // 6 months later, should be able to claim
        vm.warp(1749686400); //12-06-2025
        uint256 startDate = coreContributor.startDate;
        uint256 endDate = coreContributor.endDate;
        uint256 allocationAtStartDate = coreContributor.allocationAtStartDate;
        uint256 allocationAtEndDate = coreContributor.allocationAtEndDate;

        uint256 totalClaimed = allocationAtStartDate
            + ((allocationAtEndDate - allocationAtStartDate) * (block.timestamp - startDate)) / (endDate - startDate);

        vestingContract.claim(coreContributor.recipient);
        assertEq(theaToken.balanceOf(coreContributor.recipient), totalClaimed);

        // cannot claim anymore in the same moment
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(coreContributor.recipient);

        // last day, should be able to claim all
        vm.warp(1797033600); // 12-06-2026 (2 years after start date)
        vestingContract.claim(coreContributor.recipient);
        assertEq(theaToken.balanceOf(coreContributor.recipient), allocationAtEndDate);
    }

    function testRandomCannotClaim() public {
        address somebody = makeAddr("account");

        vm.startPrank(somebody);

        vm.warp(1733961600); //12-12-2024, after TGE
        vm.expectRevert(AllocationVesting.NothingToClaim.selector);
        vestingContract.claim(somebody);
    }

    function testCannotHaveDuplicateAllocations() public {
        vm.startPrank(deployer);
        AllocationVesting.LinearVesting[] memory allocations = new AllocationVesting.LinearVesting[](2);

        allocations[0] = theaAllocations[0];
        allocations[1] = theaAllocations[0];

        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        vm.expectRevert(
            abi.encodeWithSelector(AllocationVesting.DuplicateAllocation.selector, theaAllocations[0].recipient)
        );
        newVestingContract.setVestingSchedules(allocations);
    }

    function testCannotHaveDifferentVestedThanHalfOfMaxSupply() public {
        vm.startPrank(deployer);
        AllocationVesting.LinearVesting[] memory newAllocations = new AllocationVesting.LinearVesting[](2);

        uint256 halfTotalSupply = (100_000_000 / 2) * 10 ** 18;
        newAllocations[0] = AllocationVesting.LinearVesting(
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            halfTotalSupply,
            0,
            1718208000, //12-06-2024 (TGE)
            1781222400 // 12-06-2026 (2 years after start date)
        );

        newAllocations[1] = AllocationVesting.LinearVesting(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            10 * 10 ** 18,
            0,
            1718208000, //12-06-2024
            1749720258 // 12-06-2025
        );

        uint256 totalAllocation = halfTotalSupply + 10 * 10 ** 18;
        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        vm.expectRevert(abi.encodeWithSelector(AllocationVesting.InvalidTotalAllocation.selector, totalAllocation));
        newVestingContract.setVestingSchedules(newAllocations);
    }

    function testCannotHaveZeroAllocation() public {
        vm.startPrank(deployer);
        AllocationVesting.LinearVesting[] memory newAllocations = new AllocationVesting.LinearVesting[](2);

        newAllocations[0] = AllocationVesting.LinearVesting(
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            0,
            0,
            1718208000, //12-06-2024 (TGE)
            1781222400 // 12-06-2026 (2 years after start date)
        );

        newAllocations[1] = AllocationVesting.LinearVesting(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            100 * 10 ** 18,
            0,
            1718208000, //12-06-2024
            1749720258 // 12-06-2025
        );

        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        vm.expectRevert(
            abi.encodeWithSelector(
                AllocationVesting.ZeroAllocationForWallet.selector, 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2
            )
        );
        newVestingContract.setVestingSchedules(newAllocations);
    }

    function testInvalidVestingPeriod_sameStartAndEndDate() public {
        vm.startPrank(deployer);
        AllocationVesting.LinearVesting[] memory newAllocations = new AllocationVesting.LinearVesting[](1);

        newAllocations[0] = AllocationVesting.LinearVesting(
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            10 * 10 ** 18,
            0,
            1718208000, //12-06-2024 (TGE)
            1718208000 // 12-06-2024
        );

        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        vm.expectRevert(abi.encodeWithSelector(AllocationVesting.InvalidVestingPeriod.selector, 1718208000, 1718208000));
        newVestingContract.setVestingSchedules(newAllocations);
    }

    function testInvalidVestingPeriod_startAfterEndDate() public {
        vm.startPrank(deployer);
        AllocationVesting.LinearVesting[] memory newAllocations = new AllocationVesting.LinearVesting[](1);

        newAllocations[0] = AllocationVesting.LinearVesting(
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
            10 * 10 ** 18,
            0,
            1718208000, //12-06-2024 (TGE)
            1718064000 // 11-06-2024
        );

        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        vm.expectRevert(abi.encodeWithSelector(AllocationVesting.InvalidVestingPeriod.selector, 1718208000, 1718064000));
        newVestingContract.setVestingSchedules(newAllocations);
    }

    function testCannotSetVestingSchedulesMoreThanOnce() public {
        vm.startPrank(deployer);
        AllocationVesting newVestingContract = new AllocationVesting(address(theaToken));
        theaToken.mintTo(address(newVestingContract), 10_000_000 * 10 ** 18);
        AllocationVesting.LinearVesting[] memory newAllocations = new AllocationVesting.LinearVesting[](1);

        newAllocations[0] = AllocationVesting.LinearVesting(
            0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2, 10_000_000 * 10 ** 18, 0, 1718208000, 1718364000
        );

        newVestingContract.setVestingSchedules(newAllocations);

        theaToken.mintTo(address(newVestingContract), 10_000_000 * 10 ** 18);
        AllocationVesting.LinearVesting[] memory newAllocations2 = new AllocationVesting.LinearVesting[](1);

        newAllocations2[0] = AllocationVesting.LinearVesting(
            0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 10_000_000 * 10 ** 18, 0, 1718208000, 1718364000
        );

        vm.expectRevert(AllocationVesting.VestingSchedulesAlreadyConfigured.selector);
        newVestingContract.setVestingSchedules(newAllocations);
    }
}
