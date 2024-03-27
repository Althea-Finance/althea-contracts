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
    error CannotLock();
    error PreclaimTooLarge();
    error AllocationsMismatch();
    error ZeroTotalAllocation();
    error ZeroAllocation();
    error ZeroNumberOfWeeks();
    error DuplicateAllocation();
    error InsufficientPoints();
    error LockedAllocation();
    error SelfTransfer();
    error IncompatibleVestingPeriod(uint256 numberOfWeeksFrom, uint256 numberOfWeeksTo);

    struct AllocationSplit {
        address recipient;
        uint24 points;
        uint8 numberOfWeeks;
        uint8 weeksCliff;
        uint8 tgePct; // in basis points of 10000
    }

    struct AllocationState {
        uint24 points;
        uint8 numberOfWeeks;
        uint128 claimed;
        uint8 weeksCliff;
        uint8 tgePct;
    }

    // This number should allow a good precision in allocation fractions
    uint256 private immutable totalPoints;
    // Users allocations
    mapping(address => AllocationState) public allocations;
    // Total allocation expressed in tokens
    uint256 public immutable totalAllocation;
    ITheaToken public immutable vestingToken;
    ITokenLocker public immutable tokenLocker;
    uint256 public immutable lockToTokenRatio;
    // Vesting timeline starting timestamp
    uint256 public immutable vestingStart;

    constructor(
        ITheaToken vestingToken_,
        ITokenLocker tokenLocker_,
        uint256 totalAllocation_,
        uint256 vestingStart_,
        AllocationSplit[] memory allocationSplits
    ) {
        if (totalAllocation_ == 0) revert ZeroTotalAllocation();
        tokenLocker = tokenLocker_;
        vestingToken = vestingToken_;
        totalAllocation = totalAllocation_;
        lockToTokenRatio = tokenLocker_.lockToTokenRatio();

        vestingStart = vestingStart_;
        uint256 loopEnd = allocationSplits.length;
        uint256 total;
        for (uint256 i; i < loopEnd;) {
            address recipient = allocationSplits[i].recipient;
            uint8 numberOfWeeks = allocationSplits[i].numberOfWeeks;
            uint8 weeksCliff = allocationSplits[i].weeksCliff;
            uint8 tgePct = allocationSplits[i].tgePct;
            uint256 points = allocationSplits[i].points;
            if (points == 0) revert ZeroAllocation();
            if (numberOfWeeks == 0 && tgePct != 10000) revert ZeroNumberOfWeeks();
            if (weeksCliff > 0 && tgePct > 0) revert AllocationsMismatch();
            if (allocations[recipient].numberOfWeeks > 0 || allocations[recipient].tgePct > 0) revert DuplicateAllocation();
            total += points;
            allocations[recipient].points = uint24(points);
            allocations[recipient].numberOfWeeks = numberOfWeeks;
            allocations[recipient].weeksCliff = allocationSplits[i].weeksCliff;
            allocations[recipient].tgePct = allocationSplits[i].tgePct;
            unchecked {
                ++i;
            }
        }
        totalPoints = total;
    }

    /**
     *
     * @notice Claims accrued tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external callerOrDelegated(account) {
        AllocationState memory allocation = allocations[account];
        _claim(account, allocation.points, allocation.claimed, allocation.numberOfWeeks, allocation.weeksCliff, allocation.tgePct);
    }

    // This function exists to avoid reloading the AllocationState struct in memory
    function _claim(
        address account,
        uint256 points,
        uint256 claimed,
        uint256 numberOfWeeks,
        uint8 weeksCliff,
        uint8 tgePct
    ) private returns (uint256 claimedUpdated) {
        if (points == 0) revert NothingToClaim();
        uint256 claimable = _claimableAt(block.timestamp, points, claimed, numberOfWeeks, weeksCliff, tgePct);
        if (claimable == 0) revert NothingToClaim();
        claimedUpdated = claimed + claimable;
        allocations[account].claimed = uint128(claimedUpdated);

        vestingToken.mintToAllocationVesting(account, claimable);

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
        claimable = _claimableAt(block.timestamp,
            allocation.points,
            allocation.claimed,
            allocation.numberOfWeeks,
            allocation.weeksCliff,
            allocation.tgePct);
    }

    function _claimableAt(
        uint256 when,
        uint256 points,
        uint256 claimed,
        uint256 numberOfWeeks,
        uint8 weeksCliff,
        uint8 tgePct
    ) private view returns (uint256) {
        uint256 totalVested = _vestedAt(when, points, numberOfWeeks, weeksCliff, tgePct);
        return totalVested > claimed ? totalVested - claimed : 0;
    }

    function _vestedAt(uint256 when, uint256 points, uint256 numberOfWeeks, uint8 weeksCliff, uint8 tgePct) private view returns (uint256 vested) {
        if (vestingStart == 0 || (numberOfWeeks == 0 && tgePct != 0)) return 0;
        if (when < vestingStart) return 0;

        if (tgePct > 0) {
            vested = (totalAllocation * tgePct) / 10000;
            if (when < vestingStart + weeksCliff * 1 weeks) return vested;
        }

        if (weeksCliff > 0) {
            uint256 cliffEnd = vestingStart + weeksCliff * 1 weeks;
            if (when < cliffEnd) return 0;
        }

        uint256 vestingWeeks = numberOfWeeks * 1 weeks;
        uint256 vestingEnd = vestingStart + vestingWeeks;
        uint256 endTime = when >= vestingEnd ? vestingEnd : when;
        uint256 timeSinceStart = endTime - vestingStart;
        vested += (totalAllocation * timeSinceStart * points) / (totalPoints * vestingWeeks);
    }

    /**
     * @notice Calculates the total number of tokens left unclaimed by the user including unvested ones
     * @param account Account to calculate for
     * @return Unclaimed tokens
     */
    function unclaimed(address account) external view returns (uint256) {
        AllocationState memory allocation = allocations[account];
        uint256 accountAllocation = (totalAllocation * allocation.points) / totalPoints;
        return accountAllocation - allocation.claimed;
    }


}
