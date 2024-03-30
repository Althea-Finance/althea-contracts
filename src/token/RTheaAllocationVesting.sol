// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AllocationVesting} from "src/token/AllocationVesting.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IRTHEA is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

/// @title Vesting contract for IDO participants, redeeming rTHEA tokens
/// @author Althea, https://twitter.com/AltheaFinance, https://linktr.ee/altheafinance
/// @notice Linear vesting contract with allocations for multiple addresses with different cliffs, slopes, amounts etc.
contract RTheaAllocationVesting is AllocationVesting {
    IRTHEA public rTHEA;

    constructor(address _theaAddress) AllocationVesting(_theaAddress) {}

    function setRtheaAddress(address _rTheaAddress) external onlyOwner {
        // This is a one-time operation, and it can only be done once
        require(address(rTHEA) == address(0), "rTHEA address already set");
        rTHEA = IRTHEA(_rTheaAddress);
    }

    // no need to use delegates here, as the rTHEA can be transferred already, and they are IDO participants
    // todo make sure that this override also overrides the CallOrDelegate
    function claim(address account) external override callerOrDelegated(account) returns (uint256) {
        uint256 claimed = _claim(account);
        // If the msg.sender does not have enough rTHEA claimable to burn, the function will revert here
        // also, if the rTHEA address is not set, this will also revert, so no need to add extra checks
        rTHEA.burnFrom(msg.sender, claimed);
        return claimed;
    }
}
