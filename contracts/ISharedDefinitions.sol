// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISharedDefinitions {
      
    struct Position {
        address trader;
        uint256 amount;
        bool isLong;
        uint256 openPrice;
        uint256 leverage;
        uint256 timestamp; 
    }

    struct Trade {
        uint256 timestamp;
        uint256 traderVolume;
        uint256 totalVolumeAtTrade;
        uint256 tradeId;
    }
    
}