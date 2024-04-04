// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title oTHEA, a call option token that entitles the user to purchase THEA at a discount.
/// @author Althea (https://linktr.ee/altheafinance), (https://twitter.com/AltheaFinance)
/// @notice
///
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
contract OTheaToken is ERC20 {
    string internal constant _NAME = "call Option to purchase THEA at a discount";
    string internal constant _SYMBOL = "oTHEA";

    /// oTHEA total supply is half of THEA supply == emissions.
    uint256 public constant MAX_TOTAL_SUPPLY = 50_000_000 * 1e18;

    /// This contract handles the redemption of oTHEA in exchange for THEA.
    address public immutable oTheaRedemptions;

    error Unauthorized();

    constructor(address _oTheaRedemptions, address _oTheaDistributor) ERC20(_NAME, _SYMBOL) {
        /// oTheaDistributor will hold the oTHEA tokens to be distributed by different means
        _mint(_oTheaDistributor, MAX_TOTAL_SUPPLY);
        oTheaRedemptions = _oTheaRedemptions;
    }

    /// @notice burns rTHEA tokens from an account
    /// @dev Only the oTheaRedemptions contract is allowed to burn tokens, to be redeemed for THEA
    function burnFrom(address account, uint256 amount) external {
        if (msg.sender != oTheaRedemptions) revert Unauthorized();
        _burn(account, amount);
    }
}
