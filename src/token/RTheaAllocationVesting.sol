// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AllocationVesting} from "src/token/AllocationVesting.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IrTHEA is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

/// @title Vesting contract for IDO participants, redeeming rTHEA tokens
/// @author Althea, https://twitter.com/AltheaFinance, https://linktr.ee/altheafinance
/// @notice Linear vesting contract with allocations for multiple addresses with different cliffs, slopes, amounts etc.
///         Claims in this contract can only be performed if the account holds an equal amount of rTHEA than the vested amount to be claimed
contract RTheaAllocationVesting is AllocationVesting {
    IrTHEA public rTHEA;

    constructor(address _theaAddress) AllocationVesting(_theaAddress) {}

    /// @notice setter for the rTHEA token address
    /// @dev It can only be set once, and only by the owner. 
    function setRtheaAddress(address _rTheaAddress) external onlyOwner {
        require(address(rTHEA) == address(0), "rTHEA address already set");
        rTHEA = IrTHEA(_rTheaAddress);
    }

    /// @notice Claims vested tokens
    /// @dev Can be delegated
    ///      The `account` must hold at least the same amount of rTHEA tokens as the ones to be claimed, which will be burned
    ///      The claim will revert if rTHEA == address(0) because of not being set yet
    /// @param account Account to claim for
    function claim(address account) external override callerOrDelegated(account) returns (uint256) {
        uint256 accountRtheaBalance = rTHEA.balanceOf(account);
        // the maxClaimable is the balance of rTHEA of account, which is the max rTHEA that can be burned
        uint256 claimed = _claim(account, accountRtheaBalance);
        rTHEA.burnFrom(account, claimed);
        return claimed;
    }
}
