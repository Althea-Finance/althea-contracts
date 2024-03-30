// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title rTHEA, Receipt token from Hercules IDO vesting.
/// @author Althea (https://linktr.ee/altheafinance), (https://twitter.com/AltheaFinance)
/// @notice rTHEA can be redeemed for THEA in the RTheaAllocationVesting contract following linear vesting schedules of each participant.
///         Even though rTHEA is transferrable, it has no utility for an account without scheduled vesting in the RTheaAllocationVesting contract
///         Therefore rTHEA transfers are not recommended (besides from IDO platform to participants).
///
///                           % &&&&&&&&&&&&&&&&&& #
///                          & &&&&&&&&&&&&&&&&&& .&%
///                         &(&&&&&&&&&&&&&&&&&#  &&&&
///                        %&&&&&&&&&&&&&&&&&&*   .&&&&
///                      .,&&&&&&&&&&&&&&&&&&       %&&&
///                     # &&&&&&&&&&&&&&&&&&       %&&&&&.
///                    % &&&&&&&&&&&&&&&&&&        &&&&&&&#
///                   &,&&&&&&&&&&&&&&&&&&       (&&&&&&&&&&
///                  &/&&&&&&&&&&&&&&&&&& ,&&&&&&&&&&&&&&&&&&
///                 (&&&&&&&&&&&&&&&&&&&   .&&&&&&&&&&&&&&&&&&
///               ..&&&&&&&&&&&&&&&&&&(      &&&&&&&&&&&&&&&&&&
///              % &&&&&&&&&&&&&&&&&&*        &&&&&&&&&&&&&&&&&&*
///             & &&&&&&&&&&&&&&&&&&           &&&&&&&&&&&&&&&&&&#
///            &,&&&&&&&&&&&&&&&&&&             &&&&&&&&&&&&&&&&&&&
///           &%&&&&&&&&&&&&&&&&&&               &&&&&&&&&&&&&&&&&&&
///
contract RTheaToken is ERC20 {
    string internal constant _NAME = "Receipt Thea token from IDO";
    string internal constant _SYMBOL = "rTHEA";

    /// THEA total supply is 100 million. 15 million is allocated to the IDO,
    /// and 60% of that (9 million) is released over a vesting period.
    /// Those 9 million unvested tokens are represented by rTHEA, which can be redeemed for THEA
    /// according to each individual vesting schedule
    uint256 public constant MAX_TOTAL_SUPPLY = 9_000_000 * 1e18;

    /// This contract handles the redemption of rTHEA in echange of THEA,
    /// and therefore is the only address allowed to burn rTHEA supply.
    address public immutable rTheaAllocationVesting;

    error Unauthorized();

    constructor(address _rTHEAallocationVesting) ERC20(_NAME, _SYMBOL) {
        // The deployer will send the tokens to the launchpad platform right after deployment
        _mint(msg.sender, MAX_TOTAL_SUPPLY);
        rTheaAllocationVesting = _rTHEAallocationVesting;
    }

    /// @notice burns rTHEA tokens from an account
    /// @dev Only the rTheaAllocationVesting contract is allowed to burn tokens, to be redeemed for THEA
    function burnFrom(address account, uint256 amount) external {
        if (msg.sender != rTheaAllocationVesting) revert Unauthorized();

        _burn(account, amount);
    }
}
