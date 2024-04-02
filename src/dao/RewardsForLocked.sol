// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {IRewardsReceiver} from "src/interfaces/IRewardsReceiver.sol";

contract LockersRewardsReceiver is IRewardsReceiver {
    uint256 constant PRECISSION = 1e18;

    // units: "rewards for each asset" * PRECISSION
    uint256 public rewardsPerAsset;
    // units: "rewards for each asset" * PRECISSION
    mapping(address => uint256) claimedRewardsPerAsset;
    // units: rewards (absolute)
    mapping(address => uint256) bufferedRewards;

    // a buffer to store rewards when there are no assets 
    uint256 public nonDistributed;

    /////////////////// EVENTS & ERRORS ///////////////////

    event RewardsDepositRegistered(uint256 deposited, uint256 distributed, uint256 rewardPerAsset);

    ////////////// STATE CHANGING FUNCTIONS //////////////////

    function _registerDepositedRewards(uint256 depositedRewards, uint256 totalAssets) internal returns (bool) {
        if (totalAssets == 0) {
            nonDistributed += depositedRewards;
            return true;
        }

        // distribute the depositedRewards and the pending ones
        uint256 toDistribute = depositedRewards + nonDistributed;
        
        // review decimals lost
        uint256 _rewardsPerAsset = PRECISSION * (toDistribute) / totalAssets;
        rewardsPerAsset += _rewardsPerAsset;

        emit RewardsDepositRegistered(depositedRewards, toDistribute, _rewardsPerAsset);
    }

    function _registerClaim(address account) internal returns (uint256 claimed) {}

    function _updateAccountAssets(address account, );

    //////////////////// VIEW FUNCTIONS ///////////////////////////

}
