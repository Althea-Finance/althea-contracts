// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../dependencies/AltheaOwnable.sol";

/**
 * @title Althea LP Staking
 
    * @notice This contract allows users to stake LP tokens to earn THEA rewards.
 */
contract LPStaking is AltheaOwnable {
    using SafeERC20 for IERC20;

    address public immutable lpToken;
    address public immutable rewardToken;

    uint256 public globalRewardsPerLpToken;

    uint256 public totalStakedLp;

    mapping(address => Stake) public stakes;

    uint256 public rewardsBalance;

    struct Stake {
        address user;
        uint256 stakedLp;
        uint256 rewardsPerLpToken;
        uint256 rewards;
    }

    constructor(
        address _altheaCoreAddress,
        address _lpTokenAddress,
        address _rewardToken
    ) AltheaOwnable(_altheaCoreAddress) {
        lpToken = _lpTokenAddress;
        rewardToken = _rewardToken;
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");

        Stake storage userStake = stakes[msg.sender];
        if (userStake.user == address(0)) {
            userStake.user = msg.sender;
        }

        // update rewards
        uint256 rewards = _claimableRewards(msg.sender);
        userStake.rewards = rewards;
        rewardsBalance -= rewards;

        userStake.stakedLp += amount;
        totalStakedLp += amount;
        globalRewardsPerLpToken = rewardsBalance / totalStakedLp;
        userStake.rewardsPerLpToken = globalRewardsPerLpToken;
        IERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Cannot unstake 0");

        Stake storage userStake = stakes[msg.sender];
        require(userStake.stakedLp >= amount, "Not enough staked LP");

        // update rewards
        uint256 rewards = _claimableRewards(msg.sender);
        userStake.rewards = rewards;
        rewardsBalance -= rewards;

        userStake.stakedLp -= amount;
        totalStakedLp -= amount;
        globalRewardsPerLpToken = rewardsBalance / totalStakedLp;
        userStake.rewardsPerLpToken = globalRewardsPerLpToken;
        IERC20(lpToken).safeTransfer(msg.sender, amount);
    }

    function depositRewards(uint256 amount) external {
        require(amount > 0, "cannot deposit 0 rewards");
        rewardsBalance += amount;
        if (totalStakedLp > 0) globalRewardsPerLpToken = rewardsBalance / totalStakedLp;
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function claimRewards() external {
        Stake storage userStake = stakes[msg.sender];
        uint256 rewards = _claimableRewards(msg.sender);
        require(rewards > 0, "No rewards to claim");
        require(rewards < rewardsBalance, "Not enough rewards in the contract");
        userStake.rewards = 0;
        userStake.rewardsPerLpToken = globalRewardsPerLpToken;
        rewardsBalance -= rewards;
        IERC20(rewardToken).safeTransfer(msg.sender, rewards);
    }

    function claimableRewards(address user) external view returns (uint256) {
        return _claimableRewards(user);
    }

    function _claimableRewards(address user) internal view returns (uint256) {
        Stake storage userStake = stakes[user];
        return userStake.rewards + userStake.stakedLp * (globalRewardsPerLpToken - userStake.rewardsPerLpToken);
    }
}
