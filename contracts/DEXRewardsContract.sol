// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IDexRewardsContract.sol";
import "./DEXBaseContract.sol";
import "./ISharedDefinitions.sol";

contract DexRewardsContract is
    ISharedDefinitions,
    IDexRewardsContract,
    Ownable
{
    using SafeERC20 for IERC20;

    IERC20 public rewardsToken;
    uint256 public constant REWARD_PERIOD = 30 days;
    uint256 public constant REWARD_RATE = 387 * 10 ** 18; // Total rewards to distribute per period
    uint256 tradeNumber = 0; //resets every period
    address public dexBaseContract;
    uint256 public currentPeriodId;
    mapping(uint256 => Period) public periods;
    mapping(address => uint256) public lastClaimedPeriod;

    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _rewardsTokenAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        rewardsToken = IERC20(_rewardsTokenAddress);
        currentPeriodId = 1;
        Period storage firstPeriod = periods[currentPeriodId];
        firstPeriod.startTime = block.timestamp;
        firstPeriod.endTime = block.timestamp + REWARD_PERIOD;
        firstPeriod.totalVolume = 0;
    }

    modifier onlyDexBaseContract() {
        require(msg.sender == dexBaseContract, "Caller is not DEXBaseContract");
        _;
    }

    function recordTrade(address trader, uint256 amount) external onlyOwner {
        if (block.timestamp > periods[currentPeriodId].endTime) {
            tradeNumber = 0;
            currentPeriodId++;
            periods[currentPeriodId].startTime = block.timestamp;
            periods[currentPeriodId].endTime = block.timestamp + REWARD_PERIOD;
            periods[currentPeriodId].totalVolume = 0;
            periods[currentPeriodId].totalTradeNumber = 0;
        }
        Period storage period = periods[currentPeriodId];
        period.totalVolume += amount;
        tradeNumber++;
        period.totalTradeNumber++;
        period.trades[trader].push(
            Trade(block.timestamp, amount, period.totalVolume, tradeNumber)
        );
    }

    function isPeriodEnded() public view returns (bool) {
        return block.timestamp > periods[currentPeriodId].endTime;
    }
    function notifyNewTransaction(address trader, uint256 amount) external onlyDexBaseContract{
        // Record the transaction
        addTradeToPeriod(amount, trader);
    }
    function addTradeToPeriod(uint256 amount, address traderAddress) public onlyDexBaseContract{
        // Increment the transaction number
        tradeNumber++;
        Trade memory newTrade = Trade({
            timestamp: block.timestamp,
            traderVolume: periods[currentPeriodId].trades[traderAddress].traderVolume + amount,
            totalVolumeAtTrade: periods[currentPeriodId].totalVolumeAtTrade + amount,
            tradeNumber: tradeNumber
        });
        periods[currentPeriodId].trades[traderAddress].push(newTrade);
    }

    function addNewPeriod() public onlyDexBaseContract {
        uint256 periodEndTime;
        currentPeriodId++;
        if (periods[currentPeriodId].startTime == 0) {
            periodEndTime = block.timestamp + REWARD_PERIOD;
        } else {
            require(isPeriodEnded() == true, "Period has not ended yet");
            // If not the first period, calculate the end time based on the last period's end time
            periodEndTime =
                periods[currentPeriodId - 1].endTime +
                REWARD_PERIOD;
        }
        Period storage newPeriod = periods[currentPeriodId];
        newPeriod.startTime = block.timestamp;
        newPeriod.endTime = block.timestamp + REWARD_PERIOD;
        newPeriod.totalVolume = 0;
    }

    function claimReward(address trader) external {
        require(
            lastClaimedPeriod[trader] < currentPeriodId,
            "Rewards already claimed for the latest period"
        );

        uint256 rewardToClaim = 0;
        for (
            uint256 periodId = lastClaimedPeriod[trader] + 1;
            periodId <= currentPeriodId;
            periodId++
        ) {
            Period storage period = periods[periodId];
            Trade[] storage selectedTradersTrades = period.trades[trader];
            uint256 periodReward = 0;
            for (
                uint256 i = selectedTradersTrades[0].tradeNumber;
                i <
                period.totalTradeNumber - selectedTradersTrades[0].tradeNumber;
                i++
            ) {
                Trade storage trade = selectedTradersTrades[i];
                uint256 timeWeight = trade.timestamp -
                    selectedTradersTrades[i + 1].timestamp;
                uint256 volumeShare = trade.traderVolume /
                    trade.totalVolumeAtTrade;
                periodReward += (volumeShare * timeWeight);
            }
            periodReward *= REWARD_RATE;
            rewardToClaim += periodReward;
        }

        lastClaimedPeriod[trader] = currentPeriodId;
        if (rewardToClaim > 0) {
            rewardsToken.safeTransfer(trader, rewardToClaim);
            emit RewardPaid(trader, rewardToClaim);
        }
    }
}