// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IDexRewardsContract {
    function claimReward(address trader) external;
    function notifyNewTransaction(address trader, uint256 amount) external;
    function addNewPeriod() external;
    function isPeriodEnded() external view returns(bool);
}