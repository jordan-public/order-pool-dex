// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "@openzeppelin-contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract OrderPool is IOrderPool {
    address public owner;
    IOrderPool public reversePool;
    AggregatorV3Interface internal priceFeed;
    bool internal isPriceFeedInverse;
    IERC20 public tokenA;
    IERC20 public tokenB;

    modifier onlyOwner() {
        require(msg.sender == owner, "OrderPool: Unauthorized");
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
    }

    function setReverse(IOrderPool _reversePool) external onlyOwner {
        reversePool = _reversePool;
    }

    function getLatestPrice()
        public
        view
        returns (int256 price, uint8 decimals)
    {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        decimals = priceFeed.decimals();
        price = isPriceFeedInverse ? price : 10 ^ (decimals / price);
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) private {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "OrderPool: Transfer failed");
    }

    function swapImmediately(uint amountA) internal returns (uint amountSwapped) {
        return amountA; // !!! Not implemented
    }

    function make(uint amountA) internal {
        // !!!Not implemented
    }

    function swap(uint amountA) public {
        safeTransferFrom(tokenA, msg.sender, address(this), amountA);
        make(swapImmediately(amountA));
    }
}
