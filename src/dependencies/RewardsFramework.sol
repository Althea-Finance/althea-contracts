// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

/// @title Rewards Receiver Framework agnostic of the type of assets/rewards deposited
/// @dev The contracts inheritng this contract are responsible of calling the necessary functions everytime required
///     Everytime the assets balance of an account is going to change, _bufferRewards() MUST be called
///     This framework does NOT handle token transfers at deposits/claims
contract RewardsFramework {
    uint256 constant REWARDS_PRECISSION = 1e18;

    // note: this contract does not store the assets information. That is passed to function args here

    // units: "rewards for each asset" * REWARDS_PRECISSION
    uint256 public globalRewardsPerAsset;
    // units: "rewards for each asset" * REWARDS_PRECISSION
    mapping(address => uint256) public claimedRewardsPerAsset;
    // units: rewards (absolute)
    mapping(address => uint256) public bufferedRewards;

    // a buffer to store rewards when there are no assets
    uint256 public pendingToDistribute;

    event RewardsDepositRegistered(uint256 deposited, uint256 distributed, uint256 newRewardsPerAsset);
    event ClaimedRewards(address indexed account, uint256 claimed);

    ////////////// STATE CHANGING FUNCTIONS //////////////////

    function _registerDepositedRewards(uint256 depositedRewards, uint256 totalAssets) internal {
        if (totalAssets == 0) {
            pendingToDistribute += depositedRewards;
            emit RewardsDepositRegistered(depositedRewards, 0, globalRewardsPerAsset);
            return;
        }
        // distribute the depositedRewards and the pending ones
        uint256 toDistribute = depositedRewards + pendingToDistribute;
        // rounds down in favor of the protocol
        uint256 _rewardsPerAsset = REWARDS_PRECISSION * (toDistribute) / totalAssets;
        globalRewardsPerAsset += _rewardsPerAsset;
        emit RewardsDepositRegistered(depositedRewards, toDistribute, _rewardsPerAsset);
    }

    function _registerClaim(address account, uint256 accountAssetBalance) internal returns (uint256 claimed) {
        claimed = _pendingRewards(account, accountAssetBalance);

        // once known how much to claim, update the rewards-per-asset and reset the buffer
        claimedRewardsPerAsset[account] = globalRewardsPerAsset;
        bufferedRewards[account] = 0;

        emit ClaimedRewards(account, claimed);
        return claimed;
    }

    /// @dev This function MUST be called everytime the asset balance of account changes
    function _bufferRewards(address account, uint256 accountAssetBalanceBefore) internal {
        // overwrite the buffer and update the claimedPerAsset to match the global
        bufferedRewards[account] = _pendingRewards(account, accountAssetBalanceBefore);
        claimedRewardsPerAsset[account] = globalRewardsPerAsset;
    }

    //////////////////// VIEW FUNCTIONS ///////////////////////////

    /// @dev the output is in absolute rewards, so it has to be scaled down by PRECISSION
    function _pendingRewards(address account, uint256 accountAssetBalance) internal view returns (uint256) {
        // rounds down in favor of the protocol
        return bufferedRewards[account]
            + (accountAssetBalance * (globalRewardsPerAsset - claimedRewardsPerAsset[account])) / REWARDS_PRECISSION;
    }
}
