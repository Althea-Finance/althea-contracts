// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITheaToken} from "src/interfaces/ITheaToken.sol";
import {DelegatedOps} from "src/dependencies/DelegatedOps.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title Vesting contract for team and investors
/// @author Althea, https://twitter.com/AltheaFinance, https://linktr.ee/altheafinance
/// @notice Linear vesting contract with allocations for multiple addresses with different cliffs, slopes, amounts etc.
contract AllocationVesting is Ownable, DelegatedOps {
    error NothingToClaim();
    error ZeroAllocationForWallet(address recipient);
    error DuplicateAllocation(address recipient);
    error InvalidVestingPeriod(uint256 startDate, uint256 endDate);
    error InvalidTotalAllocation(uint256 totalAmount);
    error VestingSchedulesAlreadyConfigured();

    event ClaimedVestedTokens(address indexed account, uint256 amount);

    // not so relevant to do struct packing on an L2
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

    // 50% of the THEA's maxSupply is configured in this contract as vested tokens,
    // while the remaining 50% will be allocated to the oTHEA token, which can be redeemed for THEA 1:1
    ITheaToken public immutable THEA;

    // The sum of all allocations from all linear vestings in this contract. The sum must match 50% of THEA's maxSupply
    uint256 public totalAllocation;

    // just to keep track of how much THEA has been claimed for accounting. Doesn't include the unclaimed vested tokens
    uint256 public totalClaimed;

    // The tokens that have been already allocated to some address
    bool public vestingSchedulesConfigured;

    constructor(address _theaAddress) {
        THEA = ITheaToken(_theaAddress);
    }

    //////////////////// SETTERS OnlyOwner //////////////////////
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

        // make sure that the entire balance of this contract has been allocated
        if (THEA.balanceOf(address(this)) != totalAmount) revert InvalidTotalAllocation(totalAmount);

        // The sum of all allocations must match exaclty the expected total allocation
        totalAllocation = totalAmount;
    }

    //////////////////////// EXTERNAL ///////////////////////////

    /**
     *
     * @notice Claims vested tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external virtual callerOrDelegated(account) returns (uint256 claimed) {
        return _claim(account);
    }

    //////////////////////// VIEW ///////////////////////////

    /**
     * @notice Calculates number of tokens claimable by `account` at the current block
     * @param account Account to calculate for
     * @return claimable Accrued tokens
     */
    function claimableNow(address account) external view returns (uint256 claimable) {
        claimable = _vestedAt(block.timestamp, account) - allocations[account].claimed;
    }

    /**
     * @notice Calculates number of tokens vested at a given time `when`. It ignores if they have been claimed or not.
     * @param account Account to calculate for
     * @return Vested tokes at `when` timestamp
     */
    function vestedAt(uint256 when, address account) external view returns (uint256) {
        return _vestedAt(when, account);
    }

    //////////////////////// INTERNAL ///////////////////////////

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

    // the reason for an internal _claim is to be used by the rTHEA allocation vesting as well
    function _claim(address account) internal virtual returns (uint256 claimable) {
        // only read claimed from storage, not the full struct as it is not needed here
        claimable = _vestedAt(block.timestamp, account) - allocations[account].claimed;
        if (claimable == 0) revert NothingToClaim();

        // update storage variables
        allocations[account].claimed += claimable;
        totalClaimed += claimable;

        // No need to use SafeERC20 here, as THEA token is a trusted token
        THEA.transfer(account, claimable);
        emit ClaimedVestedTokens(account, claimable);
    }
}
