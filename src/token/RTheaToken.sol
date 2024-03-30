// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title Receipt token from Hercules IDO vesting.
/// @author Althea (https://linktr.ee/altheafinance), (https://twitter.com/AltheaFinance)
/// @notice rThea can be redeemed for THEA in the AllocationVesting contract following the linear vesting schedule.
///         Even though rThea is transferrable, it has no utility for a different account than the one
///         the vesting is set to. Therefore transfers are not recommended (besides from IDO platform to participants).
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

    // This is the 60% vested from the 15% of the total supply allocated for the IDO
    // total supply is 100 million THEA. 15 million goes for the IDO, 60% of that is 9 million, which has vesting
    uint256 public constant MAX_TOTAL_SUPPLY = 9_000_000 * 1e18; // 9 million THEA

    // The allocation vesting contract will burn rTHEA in exchange for THEA
    // when user claims THEA from the Rthea Vesting Contract
    address public immutable rTheaAllocationVesting;

    error Unauthorized();
    error TokenNotTransferrable();

    constructor(address _rTHEAallocationVesting) ERC20(_NAME, _SYMBOL) {
        // The deployer will send the tokens to the launchpad platform right after deployment
        _mint(msg.sender, MAX_TOTAL_SUPPLY);
        rTheaAllocationVesting = _rTHEAallocationVesting;
    }

    modifier onlyAllocationVesting() {
        if (msg.sender != rTheaAllocationVesting) revert Unauthorized();
        _;
    }

    // rTHEA tokens burned by the allocation vesting contract when redeeming for THEA tokens
    function burnFrom(address account, uint256 amount) external onlyAllocationVesting {
        _burn(account, amount);
    }
}
