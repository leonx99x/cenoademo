// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IDexRewardsContract.sol";
import "./DEXBaseContract.sol";
import "./ISharedDefinitions.sol";

import "hardhat/console.sol";

contract DexRewardsContract is
    ISharedDefinitions,
    IDexRewardsContract,
    Ownable
{
    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    uint256 public constant REWARD_PERIOD = 30 days;
    uint256 public constant REWARD_RATE = 387; // Total rewards to distribute per period

    uint256 lastPeriodIndex = 0; 
    uint256 lastTradeIndex = 0;
    uint256 lastPeriodEndTime = 0;
    Trade[] public trades;
    mapping(uint256 => uint256) public periodToTradeMap;
    mapping(address => uint256) public traderToTradeIdMap;
    mapping(uint256 => mapping(address => uint256[])) public periodTraderToTradeIdMap;
    mapping(address => uint256) public lastClaimedPeriod;
    address public dexBaseContract;

    event TradeRecorded(uint256 periodId, address trader, uint256 amount, uint256 tradeNumber, uint256 totalVolume);
    event RewardPaid(address indexed user, uint256 reward);
    event LogData(uint256 indexed data);

    constructor(
        address _rewardsTokenAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        rewardsToken = IERC20(_rewardsTokenAddress);
        lastPeriodIndex = 0;
        lastPeriodEndTime = block.timestamp + REWARD_PERIOD;
    }

    function setDexBaseContract(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        dexBaseContract = _address;
    }
    function getCurrentPeriodId() external view returns (uint256) {
        return lastPeriodIndex;
    }


    function isPeriodEnded() public view returns (bool) {
        return block.timestamp > lastPeriodEndTime;
    }
    function notifyNewTrade(address trader, uint256 amount) external onlyOwner{
        // Record the transaction
        addTradeToPeriod(amount, trader);
    }
    function getLastTradeForTraderInPeriod(uint256 periodId, address traderAddress) public view returns (Trade memory) {
        uint256[] storage tradeIds = periodTraderToTradeIdMap[periodId][traderAddress];
        require(tradeIds.length > 0, "Trader has no trades in this period");
        uint256 lastTradeId = tradeIds[tradeIds.length - 1];
        return trades[lastTradeId]; // Assuming you have a trades array where Trade structs are stored
    }

    function addTradeToPeriod(uint256 amount, address traderAddress) public onlyOwner{
        uint256 newTraderVolume = 0;
        if(lastPeriodEndTime < block.timestamp){
            addNewPeriod();
        }
        Trade memory newTrade;
        uint256[] storage traderTrades = periodTraderToTradeIdMap[lastPeriodIndex][traderAddress];
        if (traderTrades.length != 0) {
            // If the trader has previous trades in the current period, update the latest trade's volume
            uint256 lastTradeId = traderTrades[traderTrades.length - 1]; // Get the last trade ID for this trader in the current period
            if (lastTradeId < trades.length) {
                Trade storage lastTrade = trades[lastTradeId]; 
                newTraderVolume = lastTrade.traderVolume + amount; // Update the volume
            } 
            uint256 totalVolumeAtTrade = 0;
            if (trades.length > 0) {
                totalVolumeAtTrade = trades[trades.length - 1].totalVolumeAtTrade + amount;
            }
            newTrade = Trade({
                timestamp: block.timestamp,
                traderVolume: newTraderVolume, // Use the calculated new trader volume
                totalVolumeAtTrade: totalVolumeAtTrade,
                tradeId: lastTradeIndex + 1 // Assuming trade IDs are 1-indexed
            });
            
        } else {
            uint256 totalVolumeAtTrade = 0;
            if(trades.length > 0) {
                totalVolumeAtTrade = trades[trades.length - 1].totalVolumeAtTrade;
            }
            newTrade = Trade({
                timestamp: block.timestamp,
                traderVolume: amount, // Use the calculated new trader volume
                totalVolumeAtTrade: totalVolumeAtTrade,
                tradeId: lastTradeIndex + 1 // Assuming trade IDs are 1-indexed
            });
        }
        trades.push(newTrade); // Add the new trade to the trades array
        uint256 tradeId = trades.length; // The ID of the new trade, assuming IDs are 1-indexed based on array position
        // Map the trade ID to the trader for the current period
        periodTraderToTradeIdMap[lastPeriodIndex][traderAddress].push(tradeId);
        lastTradeIndex++; // Increment lastTradeIndex for the next trade
    }

    function addNewPeriod() public onlyOwner {
        if (lastPeriodIndex == 0) {
            lastPeriodEndTime = block.timestamp + REWARD_PERIOD;
        } else {
            require(isPeriodEnded() == true, "Period has not ended yet");
            // If not the first period, calculate the end time based on the last period's end time
            lastPeriodEndTime =
                lastPeriodEndTime +
                REWARD_PERIOD;
        }
        lastPeriodIndex++;
    }

   function claimReward(address trader) external {
    require(
        lastClaimedPeriod[trader] < lastPeriodIndex - 1,
        "Rewards already claimed for the latest period"
    );
    uint256 rewardToClaim = 0;

    for (
        uint256 periodId = lastClaimedPeriod[trader] + 1;
        periodId < lastPeriodIndex;
        periodId++
    ) {
        uint256[] storage tradeIds = periodTraderToTradeIdMap[periodId][trader];
        if(tradeIds.length == 0) continue; // Skip if no trades in this period

        uint256 periodReward = 0;
        for (uint256 i = 0; i < tradeIds.length; i++) {
            Trade storage trade = trades[tradeIds[i]]; 
            // Assuming you have a way to calculate `timeWeight` and `totalVolumeInPeriod` for the period
            uint256 timeWeight = (i < tradeIds.length - 1) ? 
                                 (trades[tradeIds[i + 1] - 1].timestamp - trade.timestamp) : 
                                 (lastPeriodEndTime - trade.timestamp);
            uint256 volumeShare = 0;
            
            if (trade.totalVolumeAtTrade > 0) {
                volumeShare = trade.traderVolume * 10**18 / trade.totalVolumeAtTrade;
            }
            console.log("timeWeight: ", timeWeight);   
            console.log("volumeShare: ", volumeShare);
            console.log("totalVolumeAtTrade: ", trade.totalVolumeAtTrade);
            periodReward += (volumeShare * timeWeight) / 10**18; // Adjust back after calculation
        }
        console.log("periodReward: ", periodReward);
        periodReward = periodReward * REWARD_RATE / 10**3; // Adjust the calculation based on your reward logic
        console.log("periodReward: ", periodReward);
        rewardToClaim += periodReward;
    }

    lastClaimedPeriod[trader] = lastPeriodIndex - 1;
    console.log("lastClaimedPeriod[trader]: ", lastClaimedPeriod[trader]);
    if (rewardToClaim > 0) {
        console.log("rewardToClaim: ", rewardToClaim);  
        rewardsToken.safeTransfer(trader, rewardToClaim);
        emit RewardPaid(trader, rewardToClaim);
    }
}
}