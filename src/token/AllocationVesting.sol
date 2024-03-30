// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DelegatedOps} from "src/dependencies/DelegatedOps.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title Vesting contract for team and investors, except for IDO participants, which claim at RTheaAllocationVesting
/// @author Althea, https://twitter.com/AltheaFinance, https://linktr.ee/altheafinance
/// @notice Linear vesting contract with allocations for multiple addresses with different cliffs, slopes, amounts etc.
contract AllocationVesting is Ownable, DelegatedOps {
    using SafeERC20 for IERC20;

    error NothingToClaim();
    error ZeroAllocationForWallet(address recipient);
    error DuplicateAllocation(address recipient);
    error InvalidVestingPeriod(uint256 startDate, uint256 endDate);
    error InvalidTotalAllocation(uint256 totalAmount);
    error VestingSchedulesAlreadyConfigured();

    event ClaimedVestedTokens(address indexed account, uint256 amount);
    event VestingSchedulesConfigured(uint256 numberOfVestingSchedules, uint256 _totalAllocation);

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

    /// Users allocations
    mapping(address => AllocationState) public allocations;

    /// Token to distribute in this contract according to vesting schedules
    IERC20 public immutable THEA;

    /// The sum of all allocations from all linear vestings in this contract.
    /// This sum must match the balance of THEA tokens of this contract when setting the vesting schedules
    uint256 public totalAllocation;

    /// Wether the vesting schedules have already been configured or not
    bool public vestingSchedulesConfigured = false; // initialized to false to disable static analysers' warnings

    /// Total amount of tokens that have been claimed from the contract
    uint256 public totalClaimed;

    constructor(address _theaAddress) {
        THEA = IERC20(_theaAddress);
    }

    //////////////////// SETTERS OnlyOwner //////////////////////

    /// @notice Function to set the vesting schedules for all receivers
    /// @dev It can only be configured once
    ///      The entire function reverts if at least one allocation is wrongly configured
    ///      It also reverts if the sum of allocations does not match this contract's balance of THEA tokens
    function setVestingSchedules(LinearVesting[] memory _linearVestings) external onlyOwner {
        // vesting schedules can only be configured once
        if (vestingSchedulesConfigured) revert VestingSchedulesAlreadyConfigured();
        vestingSchedulesConfigured = true;

        uint256 totalAmount = 0;
        uint256 loopEnd = _linearVestings.length;
        for (uint256 i; i < loopEnd; i++) {
            address recipient = _linearVestings[i].recipient;
            uint256 allocationAtEndDate = _linearVestings[i].allocationAtEndDate;
            uint256 allocationAtStartDate = _linearVestings[i].allocationAtStartDate;
            uint256 startDate = _linearVestings[i].startDate;
            uint256 endDate = _linearVestings[i].endDate;

            if (allocationAtEndDate == 0) revert ZeroAllocationForWallet(recipient);
            if (startDate >= endDate || startDate < block.timestamp) revert InvalidVestingPeriod(startDate, endDate);
            if (allocations[recipient].allocationAtEndDate > 0) revert DuplicateAllocation(recipient);

            allocations[recipient] = AllocationState({
                recipient: recipient,
                claimed: 0,
                allocationAtEndDate: allocationAtEndDate,
                allocationAtStartDate: allocationAtStartDate,
                startDate: startDate,
                endDate: endDate
            });

            totalAmount += allocationAtEndDate;
        }

        // Make sure that the entire balance of this contract has been allocated
        if (THEA.balanceOf(address(this)) != totalAmount) revert InvalidTotalAllocation(totalAmount);

        totalAllocation = totalAmount;

        emit VestingSchedulesConfigured(loopEnd, totalAmount);
    }

    //////////////////////// EXTERNAL ///////////////////////////

    /// @notice Claims vested tokens
    /// @dev Can be delegated
    /// @param account Account to claim for
    function claim(address account) external virtual callerOrDelegated(account) returns (uint256 claimed) {
        // The type(uint256).max is set because there is no restrictions on msg.senders balance before the claim
        return _claim(account, type(uint256).max);
    }

    //////////////////////// VIEW ///////////////////////////

    /// @notice Calculates number of tokens claimable by `account` at the current block
    /// @param account Account to calculate for
    /// @return claimable Accrued tokens
    function claimableNow(address account) external view returns (uint256 claimable) {
        claimable = _vestedAt(block.timestamp, account) - allocations[account].claimed;
    }

    /// @notice Calculates number of tokens vested at a given time `when`. It ignores if they have been claimed or not.
    /// @param account Account to calculate for
    /// @return Vested tokes at `when` timestamp
    function vestedAt(uint256 when, address account) external view returns (uint256) {
        return _vestedAt(when, account);
    }

    //////////////////////// INTERNAL ///////////////////////////

    /// @param account The account to claim on behalf of
    /// @param maxClaimable the max amount that can be claimed, imposed by parent implementations, like rTHEA balance of msg.sender
    /// @dev the reason for an internal `_claim()` is because this contract is inherited by RTheaAllocationVesting
    function _claim(address account, uint256 maxClaimable) internal virtual returns (uint256 claimable) {
        claimable = _vestedAt(block.timestamp, account) - allocations[account].claimed;
        if (claimable == 0) revert NothingToClaim();
        if (claimable > maxClaimable) claimable = maxClaimable;
        // We dont' want the claim to revert if the contract doesn't have enough THEA.
        // Instead, allow to claim what is there
        uint256 theaBalance = THEA.balanceOf(address(this));
        if (claimable > theaBalance) claimable = theaBalance;

        // only update storage and transfer tokens with the updated claimable, taking into account the restrictions
        allocations[account].claimed += claimable;
        totalClaimed += claimable;

        THEA.safeTransfer(account, claimable);
        emit ClaimedVestedTokens(account, claimable);
    }

    function _vestedAt(uint256 when, address recipient) private view returns (uint256 vested) {
        AllocationState memory allocation = allocations[recipient];

        uint256 startDate = allocation.startDate;
        uint256 endDate = allocation.endDate;
        uint256 allocationAtStartDate = allocation.allocationAtStartDate;
        uint256 allocationAtEndDate = allocation.allocationAtEndDate;

        // nothing vested yet
        if (when < startDate) return 0;

        // everything vested already
        if (when > endDate) return allocationAtEndDate;

        // linear interpolation between `startDate` and `when`
        uint256 timeSinceStart = when - startDate;
        uint256 totalVestingDuration = endDate - startDate; // cannot be 0, as per the requirements in the constructor
        vested = (((allocationAtEndDate - allocationAtStartDate) * timeSinceStart) / totalVestingDuration)
            + allocationAtStartDate;
    }
}
