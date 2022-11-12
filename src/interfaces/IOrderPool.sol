// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

contract IOrderPool {
    function tokenA() external view returns (IERC20);

    function tokenB() external view returns (IERC20);

    function reversePool() external view returns (IOrderPool);

    function setReverse(IOrderPool _reversePool) external;

    function getLatestPrice()
        public
        view
        returns (int256 price, uint8 decimals);

    function swap(uint256 amountA) public;

    function withdraw() external returns (uint256 amountA, uint256 amountB);
}
