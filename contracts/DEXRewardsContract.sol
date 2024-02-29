// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DexRewardsContract {

    IERC20 public rewardsToken;
    uint256 public constant REWARD_PERIOD = 30 days;
    uint256 public constant REWARD_RATE = 387; // Example rate per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalTradingVolume;
    uint256 public startTime;

    struct UserRewards {
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
        uint256 lastActiveTime;
    }

    mapping(address => uint256) public userTradingVolume;
    mapping(address => UserRewards) public userRewards;

    
}