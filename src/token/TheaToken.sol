// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OFTV2} from "lib/layerzerolabs/contracts/token/oft/v2/OFTV2.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/// @title Althea Governance Token
/// @author Althea (https://linktr.ee/altheafinance), (https://twitter.com/AltheaFinance)
/// @notice Given as an incentive for users of the protocol.
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
contract TheaToken is Ownable, OFTV2 {
    string internal constant _NAME = "Thea Governance Token";
    string internal constant _SYMBOL = "THEA";

    // max total supply hardcoded and never exceeded
    uint256 public constant MAX_TOTAL_SUPPLY = 100_000_000 * 1e18; // 100 million THEA

    error MaxSupplyExceeded();

    constructor(address _layerZeroEndpoint, uint8 _sharedDecimals)
        OFTV2(_NAME, _SYMBOL, _sharedDecimals, _layerZeroEndpoint)
    {}

    //////////////////////////// EXTERNAL //////////////////////////////

    // Ownership will be renounced right after deployment
    function mintTo(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_TOTAL_SUPPLY) revert MaxSupplyExceeded();
        _mint(to, amount);
    }
}
