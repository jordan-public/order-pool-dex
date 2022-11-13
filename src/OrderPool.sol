// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
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
    uint256 tokenADecimalsFactor;
    uint256 tokenBDecimalsFactor;
    uint256 priceDecimalsFactor;

    struct OrderType {
        address owner;
        uint256 amountAToSwap;
        uint256 cumulativeOrdersAmount;
    }

    OrderType[] public orders;
    mapping(address => uint256) public orderOwned;
    uint256 filledOrdersCummulativeAmount;
    uint256 unfilledOrdersCummulativeAmount;

    struct OrderRange {
        uint256 highIndex; // lowIndex = highIndex of previous OrderRange
        uint256 executionPrice;
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
        // owner = IOrderPoolFactory(msg.sender).owner();
        owner = msg.sender;
        priceFeed = AggregatorV3Interface(priceFeedAddress);
        tokenA = IERC20(tokenAAddress);
        tokenB = IERC20(tokenBAddress);
        tokenADecimalsFactor = 10**ERC20(tokenAAddress).decimals();
        tokenBDecimalsFactor = 10**ERC20(tokenBAddress).decimals();
        isPriceFeedInverse = _isPriceFeedInverse;
        priceDecimalsFactor = 10**priceFeed.decimals();
        orders.push(OrderType(address(0), 0, 0)); // Dummy; sentinel
    }

    function setReverse(IOrderPool _reversePool) external onlyOwner {
        reversePool = _reversePool;
    }

    function convert(uint256 amountA) public view returns (uint256 amountB) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        amountB = convertAt(amountA, uint256(price));
    }

    function convertAt(uint256 amountA, uint256 price)
        public
        view
        returns (uint256 amountB)
    {
        console.log("Price: ", price);
        amountB = isPriceFeedInverse
            ? (((amountA * priceDecimalsFactor) / price) *
                tokenBDecimalsFactor) / tokenADecimalsFactor
            : (((amountA * price) / priceDecimalsFactor) *
                tokenBDecimalsFactor) / tokenADecimalsFactor;
        console.log(
            ERC20(address(tokenA)).symbol(),
            " -> ",
            ERC20(address(tokenB)).symbol()
        );
        console.log("%s -> %s", amountA, amountB);
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

    function proxyTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external onlyReversePool {
        require(from == address(this), "OrderPool: Unauthorized");
        safeTransferFrom(token, from, to, amount);
    }

    /// To be preferrably called from UI read-only
    /// @param amountA - total amount to try to swap
    function sufficientOrderIndexSearch(uint256 amountA)
        external
        view
        returns (uint256)
    {
        assert(orders.length > 0); // As a sentinel is added in the constructor
        if (
            amountA >=
            unfilledOrdersCummulativeAmount - filledOrdersCummulativeAmount
        ) return orders.length - 1;
        for (uint256 i = orders.length - 1; i > 0; i--) {
            if (
                amountA >=
                orders[i].cumulativeOrdersAmount -
                    filledOrdersCummulativeAmount &&
                amountA <
                orders[i - 1].cumulativeOrdersAmount -
                    filledOrdersCummulativeAmount
            ) return i;
        }
        assert(false);
        return 0; // Unreachable code
    }

    /// Swap maximim amount possible
    /// @param amountA - total amount to try to swap
    /// @param payTo - the taker (who is not the caller, since this call is made from the reversePool)
    /// @param sufficientOrderIndex - the index of the order which along with the lower indexed orders can fill the maximim amount possible.
    ///     Use sufficientOrderIndexSearch() to determine this value.
    ///     If this value is usurped by another order between the last call of sufficientOrderIndexSearch() and this call, this function should revert and it has to be tried again.
    ///     Improve this !!!
    /// @param amountRemainingUnswapped - the amount left unswapped which can be placed as Maker
    function swapImmediately(
        uint256 amountA,
        address payTo,
        uint256 sufficientOrderIndex
    ) external onlyReversePool returns (uint256 amountRemainingUnswapped) {
        assert(
            unfilledOrdersCummulativeAmount >= filledOrdersCummulativeAmount
        );
        if (unfilledOrdersCummulativeAmount == filledOrdersCummulativeAmount)
            return amountA; // Empty Order Pool - all is unswapped
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
        // At this point amountA can be filled (swapped)
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
            uint256 toRemain = orders[sufficientOrderIndex]
                .cumulativeOrdersAmount -
                filledOrdersCummulativeAmount -
                amountA;
            uint256 toPayOut = orders[sufficientOrderIndex].amountAToSwap -
                toRemain;
            unfilledOrdersCummulativeAmount -= toPayOut;
            orders[sufficientOrderIndex].amountAToSwap = toRemain;
            reversePool.proxyTransferFrom(
                tokenB,
                address(reversePool),
                orders[sufficientOrderIndex].owner,
                convert(toPayOut)
            );
        }
        assert(
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                filledOrdersCummulativeAmount ==
                amountA
        );
        safeTransferFrom(tokenA, address(this), payTo, amountA);
        filledOrdersCummulativeAmount += amountA;
        (, int256 price, , , ) = priceFeed.latestRoundData();
        orderRanges.push(OrderRange(sufficientOrderIndex, uint256(price))); // So the counter-parties can determine the swap price at the time of withdrawal.
    }

    /// To be called from UI read-only
    function rangeIndexSearch() external view returns (uint256) {
        uint256 orderId = orderOwned[msg.sender];
        if (
            orderRanges.length == 0 ||
            orderRanges[orderRanges.length - 1].highIndex < orderId
        ) return type(uint256).max; // Not yet executed
        if (orderRanges.length == 1) {
            assert(orderRanges[0].highIndex >= orderId);
            return 0;
        }
        for (uint256 i = orderRanges.length - 1; i > 0; i--) {
            if (
                orderRanges[i].highIndex >= orderId &&
                orderRanges[i - 1].highIndex < orderId
            ) return i;
        }
        assert(false);
        return 0; // Unreachable code
    }

    /// Withdraw both the filled and unfilled part of the order
    /// @param rangeIndex - the index of the range (in the array of ranges) of executed entries which contains the execution price. To be determined by calling rangeIndexSearch()
    function withdraw(uint256 rangeIndex) external returns (uint256 amountB) {
        uint256 orderId = orderOwned[msg.sender];
        if (orderId != 0) {
            if (rangeIndex == type(uint256).max) {
                // Has not executed, or executed partially and paid out the executed value
                // Withdraw remaining unexecuted amount
                safeTransferFrom(
                    tokenA,
                    address(this),
                    msg.sender,
                    orders[orderId].amountAToSwap
                );
            } else {
                // Executed - pay out counter-value
                require(
                    (rangeIndex == 0 ||
                        orderRanges[rangeIndex - 1].highIndex < orderId) &&
                        orderRanges[rangeIndex].highIndex >= orderId
                );
                amountB = convertAt(
                    orders[orderId].amountAToSwap,
                    orderRanges[rangeIndex].executionPrice
                );
                reversePool.proxyTransferFrom(
                    tokenB,
                    address(reversePool),
                    msg.sender,
                    amountB
                );
            }
            orders[orderId].amountAToSwap = 0; // In either case above
        }
    }

    /// Called only for the amount which cannot be swapped immediately
    /// @param amountA - the amount to be plaved in the pool as maker
    function make(uint256 amountA) internal {
        unfilledOrdersCummulativeAmount += amountA;
        orderOwned[msg.sender] = orders.length;
        orders.push(
            OrderType(msg.sender, amountA, unfilledOrdersCummulativeAmount)
        );
    }

    /// Swap maximim amount possible and place the remaining unfilled part of the order as Maker
    /// @param amountA - total amount to try to swap
    /// @param sufficientOrderIndex - the index of the order which along with the lower indexed orders can fill the maximim amount possible.
    ///     Use sufficientOrderIndexSearch() to determine this value.
    /// See swapImmediately()
    function swap(uint256 amountA, uint256 sufficientOrderIndex) public {
        safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        make(
            reversePool.swapImmediately(
                convert(amountA),
                msg.sender,
                sufficientOrderIndex
            )
        );
    }
}
