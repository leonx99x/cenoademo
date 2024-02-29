// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IDexRewardsContract {
    function recordTradingVolume(address trader, uint256 amount) external;
    function claimRewards() external;
    function startNewPeriod() external;
}