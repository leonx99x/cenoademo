// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./DEXRewardsContract.sol";
import "./ISharedDefinitions.sol";

contract DEXBaseContract is ISharedDefinitions {
    using SafeERC20 for IERC20;
    IERC20 public baseCurrency;
    //address public priceFeed;
    uint256 public currentTime = block.timestamp;
    uint256 public mockPrice = 100 * 10**18;
    DexRewardsContract public dexRewardsContract;
    bool public isDevelopment;
    
    // Mapping of positions by trader
    mapping(address => Position[]) public positions;
    
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
		dexRewardsContract = DexRewardsContract(_dexRewardsContract);
		isDevelopment = _isDevelopment;
	}

    // events for position opened and closed
    event PositionOpened(address indexed trader, uint256 amount, bool isLong, uint256 openPrice, uint256 leverage);
    event PositionClosed(address indexed trader, uint256 amount, bool isLong, uint256 closePrice);

    //set current time for development and test purposes
    function setCurrentTime(uint256 _time) external onlyInDevelopment{
        require(_time > 0, "Time cannot be negative");
        currentTime = _time;
    }

    function _getCurrentTime() internal view returns (uint256) {
        require(currentTime > 0, "Time cannot be negative");
        return currentTime;
    }
    //mock prices setter added since oracle is not used
    function setMockPrice(uint256 _mockPrice) external onlyInDevelopment{
        require(_mockPrice > 0, "Price cannot be negative");
		mockPrice = _mockPrice;
	}
    //function to get the current price
    function getCurrentPrice() public view returns (uint256) {
        //oracle pricefeed if not development
        /* (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();  
        */
        require(mockPrice > 0, "Invalid price data");		
        return mockPrice; 
	}

     // Function to open a long or short position
    function openPosition(uint256 amount, bool isLong, uint256 leverage) external {
		if (dexRewardsContract.isPeriodEnded() || dexRewardsContract.getCurrentPeriodId() == 0){
            dexRewardsContract.addNewPeriod();
        }
        require(amount > 0, "Amount must be greater than 0");
        require(leverage >= 1, "Leverage must be at least 1");
        uint256 openPrice = getCurrentPrice();

        // Transfer base currency from trader to the contract as collateral
        baseCurrency.safeTransferFrom(msg.sender, address(this), amount);
		
        Position memory newPosition = Position({
            trader: msg.sender,
            amount: amount,
            isLong: isLong,
            openPrice: openPrice,
            leverage: leverage,
            timestamp: block.timestamp
        });

        positions[msg.sender].push(newPosition);
        dexRewardsContract.notifyNewTrade(newPosition.trader, newPosition.amount);
        emit PositionOpened(msg.sender, amount, isLong, openPrice, leverage);
    }

    // Function to close a position
    function closePosition(uint256 positionIndex) external {
		if (dexRewardsContract.isPeriodEnded() || dexRewardsContract.getCurrentPeriodId() == 0) {
            dexRewardsContract.addNewPeriod();
        }
        Position storage position = positions[msg.sender][positionIndex];
        require(position.trader == msg.sender, "Not the position owner");
        uint256 closePrice = getCurrentPrice();
        uint256 pnl;

        if (position.isLong) {
            pnl = (closePrice > position.openPrice) ? (closePrice - position.openPrice) * position.leverage : 0;
        } else {
            pnl = (closePrice < position.openPrice) ? (position.openPrice - closePrice) * position.leverage : 0;
        }

        // Calculate the amount to return to the trader
        uint256 returnAmount = position.amount + pnl;

        //transfer funds to the trader       
        baseCurrency.safeTransfer(msg.sender, returnAmount);

        // Remove the position
        delete positions[msg.sender][positionIndex];
        dexRewardsContract.notifyNewTrade(position.trader, position.amount);
        emit PositionClosed(msg.sender, position.amount, position.isLong, closePrice);
    }
}

