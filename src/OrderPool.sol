// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OrderPool {

    address owner;
    AggregatorV3Interface internal priceFeed;
    bool isPriceFeedInverse;
    IERC20 tokenA;
    IERC20 tokenB;

    constructor(address priceFeedAddress, bool _isPriceFeedInverse, address tokenAAddress, address tokenBAddress) {
        owner = IOrderPoolFactory(msg.sender).owner();
        priceFeed = AggregatorV3Interface(priceFeedAddress);
        tokenA = IERC20(tokenAAddress);
        tokenB = IERC20(tokenBAddress);
        isPriceFeedInverse = _isPriceFeedInverse;
    }

    function getLatestPrice() public view returns (int price, uint8 decimals) {
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        decimals = priceFeed.decimals();
        price = isPriceFeedInverse ? price : 10^decimals / price;
    }
}
