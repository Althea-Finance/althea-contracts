// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IRewardsReceiver {
    // @notice  deposits an `amount` of `token` of the rewards.
    //      Generally, these rewards come from emissions, so the token would be oTHEA
    // @dev     This should handle the rewards distribution among users of the Allocator
    function depositRewards(address token, uint256 amount) external;

    // user facing functions:
    function claimRewards(address token) external;
}
