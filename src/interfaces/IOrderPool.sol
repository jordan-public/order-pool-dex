// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IOrderPool {
    function tokenA() external view returns (IERC20);

    function tokenB() external view returns (IERC20);

    function reversePool() external view returns (IOrderPool);

    function setReverse(IOrderPool _reversePool) external;

    function convert(uint amountA) external view returns (uint amountB);

    function convertAt(uint amountA, uint price)
        external
        view
        returns (uint amountB);

    function proxyTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint amount
    ) external;

    function swap(uint amountA, uint sufficientOrderIndex) external;

    function swapImmediately(
        uint amountA,
        address payTo,
        uint sufficientOrderIndex
    ) external returns (uint amountRemainingUnswapped);

    function withdraw(uint rangeIndex) external returns (uint amountB);
}
