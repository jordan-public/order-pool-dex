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
    mapping(address => uint256[]) public ordersOwned;
    mapping(uint256 => uint256) public orderIndexes; // Index of the order in the array ordersOwned[owner]
    uint256 completedOrdersCummulativeAmount; // filled or withdrawn

    function availableOrdersCummulativeAmount()
        internal
        view
        returns (uint256)
    {
        // assert(orders.length > 0); // As a sentinel is added in the constructor
        return orders[orders.length - 1].cumulativeOrdersAmount;
    }

    function poolSize() external view returns (uint256) {
        return
            availableOrdersCummulativeAmount() -
            completedOrdersCummulativeAmount;
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

    modifier onlyEOA() {
        // This may cause a problem with Account Abstraction (see: https://eips.ethereum.org/EIPS/eip-4337)
        // but apparently this will be an optional feature.
        require(
            msg.sender == tx.origin,
            "OrderPool: Cannot call from contract"
        );
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
        console.log(
            "safeTransfer caller: %s token: %s",
            msg.sender,
            address(token)
        );
        console.log("to: %s amount: %s", to, amount);
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0xa9059cbb, to, amount)
        );
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
        console.log(
            "safeTransferFrom caller: %s token: %s",
            msg.sender,
            address(token)
        );
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
        console.log(
            "proxyTransfer caller: %s token: %s",
            msg.sender,
            address(tokenA)
        );
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
        // assert(orders.length > 0); // As a sentinel is added in the constructor
        if (amountA == 0) return 0;
        if (
            amountA >=
            availableOrdersCummulativeAmount() -
                completedOrdersCummulativeAmount
        ) return orders.length - 1; // Can only execute partially
        for (uint256 i = orders.length - 1; i > 0; i--) {
            if (address(0) == orders[i].owner) continue; // Withdrawn order
            if (
                amountA <=
                orders[i].cumulativeOrdersAmount -
                    completedOrdersCummulativeAmount &&
                (completedOrdersCummulativeAmount >=
                    orders[i - 1].cumulativeOrdersAmount ||
                    amountA >
                    orders[i - 1].cumulativeOrdersAmount -
                        completedOrdersCummulativeAmount)
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
    )
        external
        onlyReversePool /* onlyEOA */
        returns (uint256 amountARemainingUnswapped)
    {
        assert(
            availableOrdersCummulativeAmount() >=
                completedOrdersCummulativeAmount
        );
        if (
            availableOrdersCummulativeAmount() ==
            completedOrdersCummulativeAmount
        ) return amountA; // Empty Order Pool - all is unswapped
        if (
            amountA >
            availableOrdersCummulativeAmount() -
                completedOrdersCummulativeAmount
        ) {
            // no need to require(sufficientOrderIndex == orders.length - 1) as another order may have usurped this
            sufficientOrderIndex = orders.length - 1;
            amountARemainingUnswapped =
                (amountA + completedOrdersCummulativeAmount) -
                availableOrdersCummulativeAmount(); // extra parenthesis intended
            amountA =
                availableOrdersCummulativeAmount() -
                completedOrdersCummulativeAmount;
        } // else amountARemainingUnswapped = 0;
        // At this point amountA can be filled (swapped)
        require(
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                completedOrdersCummulativeAmount >=
                amountA,
            "OrderPool: sufficientOrderIndex too small"
        );
        require(
            sufficientOrderIndex == 0 ||
                completedOrdersCummulativeAmount >=
                orders[sufficientOrderIndex - 1].cumulativeOrdersAmount ||
                orders[sufficientOrderIndex - 1].cumulativeOrdersAmount -
                    completedOrdersCummulativeAmount <
                amountA,
            "OrderPool: sufficientOrderIndex too large"
        );
        if (
            orders[sufficientOrderIndex].cumulativeOrdersAmount -
                completedOrdersCummulativeAmount >
            amountA
        ) {
            // payout top order part immediately and adjust
            uint256 toRemainA = orders[sufficientOrderIndex]
                .cumulativeOrdersAmount -
                completedOrdersCummulativeAmount -
                amountA;
            uint256 toPayOutA = orders[sufficientOrderIndex].amountAToSwap -
                toRemainA;
            console.log("swap immediately counterparty");
            reversePool.proxyTransfer(
                tokenB,
                orders[sufficientOrderIndex].owner,
                convert(toPayOutA) // Maker pays no fees - payout the exact converted amount
            );
            orders[sufficientOrderIndex].amountAToSwap = toRemainA;
            sufficientOrderIndex--; // Did not fully fill the Maker at this index
            // At this point all orders up to and including sufficientOrderIndex-1 can withdraw
            // ... but order[sufficientOrderIndex] cannot since it was partially filled and paid out above
        }
        completedOrdersCummulativeAmount += amountA;
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
        if (
            orderRanges.length == 0 ||
            orderRanges[orderRanges.length - 1].highIndex < sufficientOrderIndex
        )
            // Should not push more than once (partial fills)
            orderRanges.push(OrderRange(sufficientOrderIndex, uint256(price))); // So the counter-parties can determine the swap price at the time of withdrawal.
    }

    function rangeIndexSearch(uint256 orderId) internal view returns (uint256) {
        // Note: msg.sender == msg.sender of the caller as this function is internal
        if (
            orderId == 0 ||
            orderRanges.length == 0 ||
            orderRanges[orderRanges.length - 1].highIndex < orderId
        ) return type(uint256).max; // Not yet fully executed or non-exsistent
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

    /// To be called from UI read-only
    function orderStatus(uint256 orderId)
        external
        view
        returns (
            uint256 remainingA,
            uint256 remainingB,
            uint256 rangeIndex
        )
    {
        if (orderId == 0) return (0, 0, type(uint256).max); // Non-existent
        rangeIndex = rangeIndexSearch(orderId);
        if (rangeIndex == type(uint256).max)
            // Not yet fully executed
            remainingA = orders[orderId].amountAToSwap;
            // remainingB = 0 as initialized
        else {
            // Fully executed
            // remainingA = 0 as initialized
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
    function withdraw(uint256 orderId, uint256 rangeIndex) external onlyEOA {
        require(orderId != 0 && orderId < orders.length, "OrderPool: Non existent order");
        require(orders[orderId].owner == msg.sender, "OrderPool: Not owner");
        assert(ordersOwned[msg.sender].length > orderIndexes[orderId] && orderId == ordersOwned[msg.sender][orderIndexes[orderId]]);
        if (rangeIndex == type(uint256).max) {
            // Has not executed, or executed partially and paid out the executed value
            // Withdraw remaining unexecuted amount
            console.log("withdraw unexecuted xfer");
            safeTransfer(tokenA, msg.sender, orders[orderId].amountAToSwap);
            // Adjust cumulativeOrdersAmount on orders issued later than this one
            for (uint256 i = orderId + 1; i < orders.length; i++)
                if (address(0) != orders[i].owner)
                    orders[i].cumulativeOrdersAmount -= orders[orderId]
                        .amountAToSwap;
        } else {
            // Executed - pay out counter-value
            require(
                (rangeIndex == 0 ||
                    orderRanges[rangeIndex - 1].highIndex < orderId) &&
                    orderRanges[rangeIndex].highIndex >= orderId
            );
            console.log("withdraw xfer");
            reversePool.proxyTransfer(
                tokenB,
                msg.sender,
                convertAt(
                    orders[orderId].amountAToSwap,
                    orderRanges[rangeIndex].executionPrice
                )
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
        orders[orderId].amountAToSwap = 0; // In either case above; redundant but safe
        // Wipe order
        if (orderId == orders.length - 1) orders.pop();
        else delete orders[orderId]; // Get gas credit
        // To avoid unnecessary exhaustive searches, remove the order from the msg.sener's ordersOwned
        if (ordersOwned[msg.sender].length != orderIndexes[orderId] + 1) { // Reuse slot in array
            ordersOwned[msg.sender][orderIndexes[orderId]] = ordersOwned[msg.sender][ordersOwned[msg.sender].length-1];
            orderIndexes[ordersOwned[msg.sender].length-1] = orderIndexes[orderId];
        }
        // orderIndexes[orderId] = 0; - no need, just discard it
        ordersOwned[msg.sender].pop();
    }

    /// Called only for the amount which cannot be swapped immediately
    /// @param amountA - the amount to be plaved in the pool as maker
    function make(uint256 amountA)
        internal
    /* no need for onlyEOA as it only increases liquidity */
        returns (uint256 orderId)
    {
        orderId = orders.length;
        orderIndexes[orderId] = ordersOwned[msg.sender].length;
        ordersOwned[msg.sender].push(orderId);
        orders.push(
            OrderType(
                msg.sender,
                amountA,
                availableOrdersCummulativeAmount() + amountA
            )
        );
    }

    /// Swap maximim amount possible and place the remaining unfilled part of the order as Maker
    /// @param amountA - total amount to try to swap
    /// @param sufficientOrderIndex - the index of the order which along with the lower indexed orders can fill the maximim amount possible.
    ///     Use sufficientOrderIndexSearch() to determine this value.
    /// See swapImmediately()
    function swap(
        uint256 amountA,
        bool taker,
        bool maker,
        uint256 sufficientOrderIndex
    ) public onlyEOA returns (uint256 orderId) {
        require(taker || maker, "OrderPool: Must be taker or maker");
        console.log("swap xfer in");
        safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        uint256 unswapped;
        if (taker)
            unswapped = reversePool.convert(
                reversePool.swapImmediately(
                    convert(amountA),
                    msg.sender,
                    sufficientOrderIndex
                )
            );
        else unswapped = amountA;
        if (maker) orderId = make(unswapped);
        else if (unswapped > 0) safeTransfer(tokenA, msg.sender, unswapped);
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
