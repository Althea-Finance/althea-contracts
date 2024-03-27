// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITheaToken} from "../interfaces/ITheaToken.sol";
import {DelegatedOps} from "../dependencies/DelegatedOps.sol";
import {ITokenLocker} from "../interfaces/ITokenLocker.sol";

/**
 * @title Vesting contract for team and investors
 * @author PrismaFi
 * @notice Vesting contract which allows transfer of future vesting claims
 */
contract AllocationVesting is DelegatedOps {
    error NothingToClaim();
    error ZeroTotalAllocation();
    error ZeroAllocationForWallet(address recipient);
    error DuplicateAllocation();
    error IncompatibleVestingPeriod(uint256 numberOfWeeksFrom, uint256 numberOfWeeksTo);
    error TooMuchAllocation();

    event VestingClaimed(address indexed account, uint256 amount);

    struct LinearVesting {
        address recipient;
        uint256 allocationAtEndDate; // in tokens
        uint256 allocationAtStartDate; // in tokens
        uint256 startDate;
        uint256 endDate;
    }

    struct AllocationState {
        address recipient;
        uint256 claimed; // in tokens
        uint256 allocationAtEndDate; // in tokens
        uint256 allocationAtStartDate; // in tokens
        uint256 startDate;
        uint256 endDate;
    }

    // Users allocations
    mapping(address => AllocationState) public allocations;

    ITheaToken public immutable vestingToken;
    uint256 public immutable totalAllocation;

    constructor(ITheaToken _vestingToken, LinearVesting[] memory _allocations) {
        vestingToken = _vestingToken;

        totalAllocation = _vestingToken.totalSupply() / 2; // only vest 50% of the total supply, the rest are Emissions
        if (totalAllocation == 0) revert ZeroTotalAllocation();

        uint256 loopEnd = _allocations.length;
        uint256 totalVesting = 0;
        for (uint256 i; i < loopEnd; ) {
            address recipient = _allocations[i].recipient;
            uint256 allocationAtEndDate = _allocations[i].allocationAtEndDate;

            uint256 allocationAtStartDate = _allocations[i].allocationAtStartDate;
            uint256 startDate = _allocations[i].startDate;
            uint256 endDate = _allocations[i].endDate;
            if (allocationAtEndDate == 0) revert ZeroAllocationForWallet(recipient);
            if (startDate == 0 || endDate == 0 || startDate >= endDate || startDate == endDate)
                revert IncompatibleVestingPeriod(startDate, endDate);
            if (allocations[recipient].allocationAtEndDate > 0) revert DuplicateAllocation();

            allocations[recipient] = AllocationState(
                recipient,
                0,
                allocationAtEndDate,
                allocationAtStartDate,
                startDate,
                endDate
            );

            totalVesting += allocationAtEndDate;
            if (totalVesting > totalAllocation) revert TooMuchAllocation();

            unchecked {
                ++i;
            }
        }
    }

    /**
     *
     * @notice Claims accrued tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external callerOrDelegated(account) {
        AllocationState memory allocation = allocations[account];
        uint256 amount = _claim(allocation);
        emit VestingClaimed(account, amount);
    }

    // This function exists to avoid reloading the AllocationState struct in memory
    function _claim(AllocationState memory allocation) private returns (uint256 claimedUpdated) {
        address recipient = allocation.recipient;
        uint256 claimable = _claimableAt(
            block.timestamp,
            allocation.allocationAtStartDate,
            allocation.allocationAtEndDate,
            allocation.startDate,
            allocation.endDate,
            allocation.claimed
        );
        if (claimable == 0) revert NothingToClaim();
        claimedUpdated = allocation.claimed + claimable;
        allocations[recipient].claimed = claimedUpdated;

        vestingToken.mintToAllocationVesting(recipient, claimable);

        // We send to delegate for possible zaps
        //        vestingToken.transferFrom(vault, msg.sender, claimable);
    }

    /**
     * @notice Calculates number of tokens claimable by the user at the current block
     * @param account Account to calculate for
     * @return claimable Accrued tokens
     */
    function claimableNow(address account) external view returns (uint256 claimable) {
        AllocationState memory allocation = allocations[account];
        claimable = _claimableAt(
            block.timestamp,
            allocation.allocationAtStartDate,
            allocation.allocationAtEndDate,
            allocation.startDate,
            allocation.endDate,
            allocation.claimed
        );
    }

    function _claimableAt(
        uint256 when,
        uint256 allocationAtStartDate,
        uint256 allocationAtEndDate,
        uint256 startDate,
        uint256 endDate,
        uint256 claimed
    ) private pure returns (uint256) {
        uint256 totalVested = _vestedAt(when, allocationAtStartDate, allocationAtEndDate, startDate, endDate);
        return totalVested > claimed ? totalVested - claimed : 0;
    }

    function _vestedAt(
        uint256 when,
        uint256 allocationAtStartDate,
        uint256 allocationAtEndDate,
        uint256 startDate,
        uint256 endDate
    ) private pure returns (uint256 vested) {
        if (when == 0 || startDate == 0 || endDate == 0 || startDate > endDate || allocationAtEndDate == 0) return 0;
        if (when < startDate) return 0;

        uint256 endTime = when >= endDate ? endDate : when;
        uint256 timeSinceStart = endTime - startDate;
        uint256 totalVestingTime = endDate - startDate; //cannot be 0
        vested =
            (((allocationAtEndDate - allocationAtStartDate) * timeSinceStart) / totalVestingTime) +
            allocationAtStartDate;
    }
}
