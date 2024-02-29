// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DEXRewardsContract.sol";


contract DEXBaseContract {
    IERC20 public baseCurrency;
    //address public priceFeed;
    uint256 public currentTime = block.timestamp;
    uint256 public mockPrice = 1000 * 10**18;
    DEXRewardsContract public dexRewardsContract;
    bool public isDevelopment;

    // Mapping of positions by trader
    mapping(address => Position[]) public positions;

    struct Position {
        address trader;
        uint256 amount;
        bool isLong;
        uint256 openPrice;
        uint256 leverage;
    }
	// modifier for development mode
    modifier onlyInDevelopment() {
		require(isDevelopment, "This function is only available in development mode.");
		_;
	}
    /*
    *constructor(address _baseCurrency, address _priceFeed, address _dexRewardsContract, bool _isDevelopment) {
	*	baseCurrency = IERC20(_baseCurrency);
	*	priceFeed = AggregatorV3Interface(_priceFeedAddress);
	*	dexRewardsContract = DEXRewardsContract(_dexRewardsContract);
	*   isDevelopment = _isDevelopment;
	*}
	*/
	
	constructor(address _baseCurrency, address _dexRewardsContract, bool _isDevelopment) {
		baseCurrency = IERC20(_baseCurrency);
		dexRewardsContract = DEXRewardsContract(_dexRewardsContract);
		isDevelopment = _isDevelopment;
	}
    //set current time for development and test purposes
    function setCurrentTime(uint256 _time) external onlyInDevelopment{
        currentTime = _time;
    }

    function _getCurrentTime() internal view returns (uint256) {
        return currentTime;
    }
    
}

