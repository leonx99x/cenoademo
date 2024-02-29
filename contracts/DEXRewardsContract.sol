// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
//import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DexRewardsContract {

    IERC20 public rewardsToken;
    uint256 public constant REWARD_PERIOD = 30 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalTradingVolume;
    uint256 public startTime;
    address public dexBaseContract;
    uint256 public constant TOTAL_REWARD = 387 * 10**18;
    uint256 public constant REWARD_RATE = TOTAL_REWARD / REWARD_PERIOD; 

    struct UserRewards {
        uint256 userRewardPerTokenPaid;
        uint256 rewards;
        uint256 lastActiveTime;
    }

    mapping(address => uint256) public userTradingVolume;
    mapping(address => UserRewards) public userRewards;

    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _rewardsTokenAddress) {
        rewardsToken = IERC20(_rewardsTokenAddress);
        startTime = block.timestamp;
        lastUpdateTime = block.timestamp;
    }
    function calculateReward(uint256 userVolume, uint256 totalVolume) public view returns (uint256) {
        if (totalVolume == 0) return 0;

        uint256 userShare = (userVolume * REWARD_RATE * (lastTimeRewardApplicable() - lastUpdateTime)) / totalVolume;
        return userShare; // Scale down as necessary depending on how REWARD_RATE was scaled up
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            userRewards[account].rewards = earned(account);
            userRewards[account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }
	function recordTradingVolume(address trader, uint256 amount) external {
        require(msg.sender == address(dexBaseContract), "Only the DEX contract can call this function");

        // Update the last active time for the trader
        UserRewards storage userReward = userRewards[trader];
        userReward.lastActiveTime = block.timestamp;

        // Update trading volume if within the current reward period
        if (block.timestamp <= startTime + REWARD_PERIOD) {
            userTradingVolume[trader] += amount;
            totalTradingVolume += amount;
        }
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp > startTime + REWARD_PERIOD ? startTime + REWARD_PERIOD : block.timestamp;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalTradingVolume == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) * REWARD_RATE) / totalTradingVolume);
    }

    function earned(address account) public view returns (uint256) {
        return (userTradingVolume[account] *
                (rewardPerToken() - userRewards[account].userRewardPerTokenPaid) +
                userRewards[account].rewards) / 10**18;
    }
    function setDexBaseContract(address _address) external  onlyOwner {
        dexBaseContract = _address;
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalTradingVolume += amount;
        userTradingVolume[msg.sender] += amount;
        userRewards[msg.sender].lastActiveTime = block.timestamp;
    }
    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        totalTradingVolume -= amount;
        userTradingVolume[msg.sender] -= amount;
        // Return the tokens to the user
    }

    function getReward() external updateReward(msg.sender) {
        uint256 reward = userRewards[msg.sender].rewards;
        if (reward > 0) {
            userRewards[msg.sender].rewards = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
	function claimRewards() external {
        require(userRewards[msg.sender].lastActiveTime >= startTime, "No operations in the current period");
        uint256 reward = earned(msg.sender);
        
        // Ensure these state changes happen after calculations and before the transfer
        userTradingVolume[msg.sender] = 0;
        userRewards[msg.sender].rewards = 0;
        userRewards[msg.sender].lastActiveTime = block.timestamp;
        
        // Transfer the reward to the trader
        rewardsToken.transfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
        
        // Reset the trading volume if a new period started
        if (block.timestamp > startTime + REWARD_PERIOD) {
            startTime = block.timestamp;
            totalTradingVolume = 0;
        }
    }

}