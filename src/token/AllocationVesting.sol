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
    error DuplicateAllocation(address recipient);
    error InvalidVestingPeriod(uint256 startDate, uint256 endDate);
    error InvalidTotalAllocation();

    event VestingClaimed(address indexed account, uint256 amount);

    struct LinearVesting {
        // @audit-info we could use some storage packing here to save gas. But not important
        address recipient;
        uint256 allocationAtEndDate; // in tokens
        uint256 allocationAtStartDate; // in tokens
        uint256 startDate;
        uint256 endDate;
    }

    struct AllocationState {
        // @audit-info we could use some storage packing here to save gas. But not important
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
    ITheaToken public immutable vestingToken;

    // The sum of all allocations from all linear vestings in this contract. The sum must match 50% of THEA's maxSupply
    uint256 public immutable totalAllocation;

    constructor(ITheaToken _vestingToken, LinearVesting[] memory _linearVestings) {
        vestingToken = _vestingToken;

        // @audit make sure this assumption of 50% supply here is correct after talking to Hercules launchpad, in case they do IDO vestings
        uint256 _totalVestedAllocation = _vestingToken.maxTotalSupply() / 2; // only vest 50% of the total supply, the rest are Emissions
        if (_totalVestedAllocation == 0) revert ZeroTotalAllocation();

        uint256 loopEnd = _linearVestings.length;
        uint256 totalAmount = 0;
        for (uint256 i; i < loopEnd; i++) {
            address recipient = _linearVestings[i].recipient;
            uint256 allocationAtEndDate = _linearVestings[i].allocationAtEndDate;
            uint256 allocationAtStartDate = _linearVestings[i].allocationAtStartDate;
            uint256 startDate = _linearVestings[i].startDate;
            uint256 endDate = _linearVestings[i].endDate;

            if (allocationAtEndDate == 0) revert ZeroAllocationForWallet(recipient);

            if (startDate >= endDate || startDate < block.timestamp) revert InvalidVestingPeriod(startDate, endDate);
            if (allocations[recipient].allocationAtEndDate > 0) revert DuplicateAllocation(recipient);

            allocations[recipient] =
                AllocationState(recipient, 0, allocationAtEndDate, allocationAtStartDate, startDate, endDate);

            totalAmount += allocationAtEndDate;
        }
        // The sum of all allocations must match exaclty the expected total allocation
        if (totalAmount != _totalVestedAllocation) revert InvalidTotalAllocation();
        totalAllocation = totalAmount;
    }

    /**
     *
     * @notice Claims vested tokens
     * @dev Can be delegated
     * @param account Account to claim for
     */
    function claim(address account) external callerOrDelegated(account) {
        uint256 claimed = allocations[account].claimed; // only read claimed from storage, not the full struct as it is not needed here
        uint256 claimable = _vestedAt(block.timestamp, account) - claimed;

        if (claimable == 0) revert NothingToClaim();

        allocations[account].claimed = claimed + claimable;
        vestingToken.mintTo(account, claimable);

        emit VestingClaimed(account, claimable);
    }

    /**
     * @notice Calculates number of tokens claimable by the user at the current block
     * @param account Account to calculate for
     * @return claimable Accrued tokens
     */
    function claimableNow(address account) external view returns (uint256 claimable) {
        claimable = _vestedAt(block.timestamp, account) - allocations[account].claimed;
    }

    function vestedAt(uint256 when, address account) external view returns (uint256) {
        return _vestedAt(when, account);
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

        uint256 timeSinceStart = when - startDate;
        uint256 totalVestingDuration = endDate - startDate; // cannot be 0, as per the requirements in the constructor
        vested = (((allocationAtEndDate - allocationAtStartDate) * timeSinceStart) / totalVestingDuration)
            + allocationAtStartDate;
    }
}
