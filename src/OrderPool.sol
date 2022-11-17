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

    uint256 public feesToCollect; // = 0;
    uint16 public constant FEE_DENOM = 10000;
    uint16 public constant FEE_TAKER_TO_MAKER = 25; // 0.25%
    uint16 public constant FEE_TAKER_TO_PROTOCOL = 5; // 0.05%

    struct OrderType {
        address owner;
        uint256 amountAToSwap;
        uint256 cumulativeOrdersAmount;
    }

    OrderType[] public orders;
    mapping(address => uint256) public orderOwned;
    uint256 filledOrdersCummulativeAmount;

    function unfilledOrdersCummulativeAmount() internal view returns (uint256) {
        if (orders.length == 0) return 0;
        return orders[orders.length - 1].cumulativeOrdersAmount;
    }

    function poolSize() external view returns (uint256) {
        return
            unfilledOrdersCummulativeAmount() - filledOrdersCummulativeAmount;
    }

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
        amountB = isPriceFeedInverse
            ? (amountA * priceDecimalsFactor * tokenBDecimalsFactor) /
                (price * tokenADecimalsFactor)
            : (amountA * price * tokenBDecimalsFactor) /
                (priceDecimalsFactor * tokenADecimalsFactor);
    }

    // To cover "transfer" calls which return bool and/or revert
    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
console.log("safeTransfer caller: %s token: %s", msg.sender, address(token));
console.log("to: %s amount: %s", to, amount);
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "OrderPool: transfer failed"
        );
    }

    // To cover "transfer" calls which return bool and/or revert
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
console.log("safeTransferFrom caller: %s token: %s", msg.sender, address(token));
console.log("from: %s to: %s amount: %s", from, to, amount);
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "OrderPool: transferFrom failed"
        );
    }

    function proxyTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) external onlyReversePool {
console.log("proxyTransfer caller: %s token: %s", msg.sender, address(tokenA));
console.log("to: %s amount: %s", to, amount);
        safeTransfer(token, to, amount);
    }

    /// To be preferrably called from UI read-only
    /// @param amountA - total amount to try to swap
    function sufficientOrderIndexSearch(uint256 amountA)
        external
        view
        returns (uint256)
    {
        return reversePool.sufficientOrderIndexSearchRP(convert(amountA));
    }

    /// To be preferrably called from UI read-only
    /// @param amountA - total amount to try to swap
    function sufficientOrderIndexSearchRP(uint256 amountA)
        external
        view
        returns (uint256)
    {
        assert(orders.length > 0); // As a sentinel is added in the constructor
        if (
            amountA >=
            unfilledOrdersCummulativeAmount() - filledOrdersCummulativeAmount
        ) return orders.length - 1;
        for (uint256 i = orders.length - 1; i > 0; i--) {
            if (
                amountA <=
                orders[i].cumulativeOrdersAmount -
                    filledOrdersCummulativeAmount &&
                amountA >
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
    /// @return amountARemainingUnswapped - the amount left unswapped which can be placed as Maker
    function swapImmediately(
        uint256 amountA,
        address payTo,
        uint256 sufficientOrderIndex
    ) external onlyReversePool returns (uint256 amountARemainingUnswapped) {
        assert(
            unfilledOrdersCummulativeAmount() >= filledOrdersCummulativeAmount
        );
        if (unfilledOrdersCummulativeAmount() == filledOrdersCummulativeAmount)
            return amountA; // Empty Order Pool - all is unswapped
        if (
            amountA >
            unfilledOrdersCummulativeAmount() - filledOrdersCummulativeAmount
        ) {
            // no need to require(sufficientOrderIndex == orders.length - 1) as another order may have usurped this
            sufficientOrderIndex = orders.length - 1;
            amountARemainingUnswapped =
                (amountA + filledOrdersCummulativeAmount) -
                    unfilledOrdersCummulativeAmount(); // extra parenthesis intended
            amountA =
                unfilledOrdersCummulativeAmount() -
                filledOrdersCummulativeAmount;
        } // else amountARemainingUnswapped = 0;
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
            uint256 toRemainA = orders[sufficientOrderIndex]
                .cumulativeOrdersAmount -
                filledOrdersCummulativeAmount -
                amountA;
            uint256 toPayOutA = orders[sufficientOrderIndex].amountAToSwap -
                toRemainA;
            orders[sufficientOrderIndex].amountAToSwap = toRemainA;
            sufficientOrderIndex--; // Did not fully fill the order at this index
console.log("swap immediately counterparty");
            reversePool.proxyTransfer(
                tokenB,
                orders[sufficientOrderIndex].owner,
                convert(toPayOutA) // Maker pays no fees - payout the exact converted amount
            );
        }
        // At this point all orders up to and including sufficientOrderIndex-1 can withdraw
        // ... but order[sufficientOrderIndex] cannot since it was partially filled and paid out above
        filledOrdersCummulativeAmount += amountA;
        uint256 feeToProtocol = (amountA * FEE_TAKER_TO_PROTOCOL) / FEE_DENOM;
        feesToCollect += feeToProtocol;
        amountA -= feeToProtocol;
console.log("swap immediately xfer");
        safeTransfer(
            tokenA,
            payTo,
            (amountA * (FEE_DENOM - FEE_TAKER_TO_MAKER - 1)) / FEE_DENOM // Payout less to compensate for fees; the "- 1" compensates for rounding
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        orderRanges.push(OrderRange(sufficientOrderIndex, uint256(price))); // So the counter-parties can determine the swap price at the time of withdrawal.
    }

    /// To be called from UI read-only
    function rangeIndexSearch() internal view returns (uint256) {
        uint256 orderId = orderOwned[msg.sender];
        if (
            orderId == 0 ||
            orderRanges.length == 0 ||
            orderRanges[orderRanges.length - 1].highIndex < orderId
        ) return type(uint256).max; // Not yet executed or non-exsistent
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

    function orderStatus()
        external
        view
        returns (
            uint256 remainingA,
            uint256 remainingB,
            uint256 rangeIndex
        )
    {
        uint256 orderId = orderOwned[msg.sender];
        if (orderId == 0) return (0, 0, type(uint256).max); // Non-existent
        rangeIndex = rangeIndexSearch();
        if (rangeIndex == type(uint256).max)
            remainingA = orders[orderId].amountAToSwap;
        else {
            // otherwise remainingB = 0 as initialized
            remainingB = convertAt(
                orders[orderId].amountAToSwap,
                orderRanges[rangeIndex].executionPrice
            );
            // Do not report: remainingA = (((orders[orderId].amountAToSwap *
            //         (FEE_DENOM - FEE_TAKER_TO_PROTOCOL)) / FEE_DENOM) *
            //         FEE_TAKER_TO_MAKER) / FEE_DENOM; // Fees to collect
        }
    }

    /// Withdraw both the filled and unfilled part of the order
    /// @param rangeIndex - the index of the range (in the array of ranges) of executed entries which contains the execution price. To be determined by calling rangeIndexSearch()
    function withdraw(uint256 rangeIndex) external returns (uint256 amountB) {
        uint256 orderId = orderOwned[msg.sender];
        require(orderId != 0, "OrderPool: Non existent order");
        if (rangeIndex == type(uint256).max) {
            // Has not executed, or executed partially and paid out the executed value
            // Withdraw remaining unexecuted amount
            // !!! not allowed as it would trow off the calculations of available capital
            // safeTransfer(
            //     tokenA,
            //     msg.sender,
            //     orders[orderId].amountAToSwap
            // );
            // Also would have to re-calculate unfilledOrdersCummulativeAmount
            revert("OrderPool: Not allowed");
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
console.log("withdraw xfer");
            reversePool.proxyTransfer(
                tokenB,
                msg.sender,
                amountB
            );
console.log("withdraw xfer fees");
            safeTransfer(
                tokenA,
                msg.sender,
                (((orders[orderId].amountAToSwap *
                    (FEE_DENOM - FEE_TAKER_TO_PROTOCOL)) / FEE_DENOM) *
                    FEE_TAKER_TO_MAKER) / FEE_DENOM
            );
        }
        orders[orderId].amountAToSwap = 0; // In either case above
        // Wipe order
        delete orders[orderId]; // Get gas credit
        orderOwned[msg.sender] = 0; // To avoid unnecessary exhaustive searches
    }

    /// Called only for the amount which cannot be swapped immediately
    /// @param amountA - the amount to be plaved in the pool as maker
    function make(uint256 amountA) internal {
        orderOwned[msg.sender] = orders.length;
        orders.push(
            OrderType(
                msg.sender,
                amountA,
                unfilledOrdersCummulativeAmount() + amountA
            )
        );
    }

    /// Swap maximim amount possible and place the remaining unfilled part of the order as Maker
    /// @param amountA - total amount to try to swap
    /// @param sufficientOrderIndex - the index of the order which along with the lower indexed orders can fill the maximim amount possible.
    ///     Use sufficientOrderIndexSearch() to determine this value.
    /// See swapImmediately()
    function swap(uint256 amountA, uint256 sufficientOrderIndex) public {
console.log("swap xfer in");
        safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        make(
            reversePool.convert(
                reversePool.swapImmediately(
                    convert(amountA),
                    msg.sender,
                    sufficientOrderIndex
                )
            )
        );
    }

    function withdrawFees(address payTo)
        external
        onlyOwner
        returns (uint256 collected)
    {
console.log("withdraw fees");
        safeTransfer(tokenA, payTo, feesToCollect);
        collected = feesToCollect;
        feesToCollect = 0;
    }
}
