// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "chainlink/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IOrderPool.sol";
import "./interfaces/IOrderPoolFactory.sol";

contract OrderPool is IOrderPool {
    address public owner;
    IOrderPool public reversePool;
    AggregatorV3Interface public priceFeed;
    bool public isPriceFeedInverse;
    IERC20 public tokenA;
    IERC20 public tokenB;
    uint priceDecimalsFactor;

    struct OrderType {
        address owner;
        uint amountAToSwap;
        uint cumulativeOrdersAmount;
    }

    OrderType[] public orders;
    mapping (address => uint) public orderOwned;
    uint filledOrdersCummulativeAmount;
    uint unfilledOrdersCummulativeAmount;

    struct OrderRange {
        uint highIndex;
        uint executionPrice;
    }
    OrderRange[] public orderRanges;

    modifier onlyOwner() {
        require(msg.sender == owner, "OrderPool: Unauthorized");
        _;
    }

    modifier onlyReversePool() {
        require(msg.sender == address(reversePool), "OrderPool: Unauthorized");
        _;
    }

    constructor(
        address priceFeedAddress,
        bool _isPriceFeedInverse,
        address tokenAAddress,
        address tokenBAddress
    ) {
        owner = IOrderPoolFactory(msg.sender).owner();
        priceFeed = AggregatorV3Interface(priceFeedAddress);
        tokenA = IERC20(tokenAAddress);
        tokenB = IERC20(tokenBAddress);
        isPriceFeedInverse = _isPriceFeedInverse;
        priceDecimalsFactor = 10 ^ priceFeed.decimals();
    }

    function setReverse(IOrderPool _reversePool) external onlyOwner {
        reversePool = _reversePool;
    }

    function convert(uint amountA) public view returns (uint amountB) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        amountB = isPriceFeedInverse
            ? (amountA * priceDecimalsFactor) / uint(price)
            : (amountA * uint(price)) / priceDecimalsFactor;
    }

    function convertAt(uint amountA, uint price) public view returns (uint amountB) {
        amountB = isPriceFeedInverse
            ? (amountA * priceDecimalsFactor) / price
            : (amountA * price) / priceDecimalsFactor;
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "OrderPool: Transfer failed"
        );
    }

    function proxyTransferFrom(IERC20 token, address from, address to, uint amount) external onlyReversePool {
        require(from == address(this), "OrderPool: Unauthorized");
        safeTransferFrom(token, from, to, amount);
    }

    function swapImmediately(uint amountA, address payTo, uint sufficientOrderIndex)
        external
        onlyReversePool
        returns (uint amountRemainingUnswapped)
    {
        assert(
            unfilledOrdersCummulativeAmount >= filledOrdersCummulativeAmount
        );
        if (unfilledOrdersCummulativeAmount == filledOrdersCummulativeAmount)
            return 0; // Empty Order Pool
        if (
            amountA >=
            unfilledOrdersCummulativeAmount - filledOrdersCummulativeAmount
        ) {
            // no need to require(sufficientOrderIndex == orders.length - 1) as another order may have usurped this
            sufficientOrderIndex = orders.length - 1;
            amountRemainingUnswapped = convert(
                (amountA + filledOrdersCummulativeAmount) -
                    unfilledOrdersCummulativeAmount
            ); // extra parenthesis intended
            amountA =
                unfilledOrdersCummulativeAmount -
                filledOrdersCummulativeAmount;
        } // else amountRemainingUnswapped = 0;
        require(
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                filledOrdersCummulativeAmount >=
                amountA,
            "OrderPool: sufficientOrderIndex too small"
        );
        require(
            sufficientOrderIndex == 0 ||
                orders[sufficientOrderIndex - 1].cumulativeOrdersAmount -
                    filledOrdersCummulativeAmount <
                amountA,
            "OrderPool: sufficientOrderIndex too large"
        );
        if (
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                filledOrdersCummulativeAmount >
            amountA
        ) {
            // payout top order part immediately and adjust
            uint toRemain = orders[sufficientOrderIndex].cumulativeOrdersAmount - filledOrdersCummulativeAmount - amountA;
            uint toPayOut = orders[sufficientOrderIndex].amountAToSwap - toRemain;
            unfilledOrdersCummulativeAmount -= toPayOut;
            orders[sufficientOrderIndex].amountAToSwap = toRemain;
            reversePool.proxyTransferFrom(tokenB, address(reversePool), orders[sufficientOrderIndex].owner, convert(toPayOut));
        }
        assert(
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                filledOrdersCummulativeAmount ==
                amountA
        );
        safeTransferFrom(tokenA, address(this), payTo, amountA);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        orderRanges.push(OrderRange(sufficientOrderIndex, uint(price)));
    }

    function withdraw(uint rangeIndex) external returns (uint amountB) {
        uint orderId = orderOwned[msg.sender];
        require((rangeIndex == 0 || orderRanges[rangeIndex-1].highIndex < orderId) && orderRanges[rangeIndex].highIndex >= orderId);
        amountB = convertAt(orders[orderId].amountAToSwap, orderRanges[rangeIndex].executionPrice);
        reversePool.proxyTransferFrom(tokenB, address(reversePool), msg.sender, amountB);
        orders[orderId].amountAToSwap = 0;
    }

    function make(uint amountA) internal {
        unfilledOrdersCummulativeAmount += amountA;
        orderOwned[msg.sender] = orders.length;
        orders.push(OrderType(msg.sender, amountA, unfilledOrdersCummulativeAmount));
    }

    function swap(uint amountA, uint sufficientOrderIndex) public {
        safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        make(reversePool.swapImmediately(convert(amountA), msg.sender, sufficientOrderIndex));
    }
}
