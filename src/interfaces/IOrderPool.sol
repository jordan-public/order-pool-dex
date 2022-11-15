// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/IERC20.sol";

interface IOrderPool {
    function tokenA() external view returns (IERC20);

    function tokenB() external view returns (IERC20);

    function reversePool() external view returns (IOrderPool);

    function setReverse(IOrderPool _reversePool) external;

    function isPriceFeedInverse() external view returns (bool);

    function convert(uint256 amountA) external view returns (uint256 amountB);

    function convertAt(uint256 amountA, uint256 price)
        external
        view
        returns (uint256 amountB);

    function proxyTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external;

    function sufficientOrderIndexSearch(uint256 amountA)
        external
        view
        returns (uint256);

    function sufficientOrderIndexSearchRP(uint256 amountA)
        external
        view
        returns (uint256);

    function swapImmediately(
        uint256 amountA,
        address payTo,
        uint256 sufficientOrderIndex
    ) external returns (uint256 amountRemainingUnswapped);

    function swap(uint256 amountA, uint256 sufficientOrderIndex) external;

    function rangeIndexSearch() external view returns (uint256);

    function withdraw(uint256 rangeIndex) external returns (uint256 amountB);

    function feesToCollect() external view returns (uint256);

    function withdrawFees(address payTo) external returns (uint256);
}
