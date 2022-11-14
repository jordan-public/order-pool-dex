// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./IOrderPool.sol";

interface IOrderPoolFactory {
    function owner() external view returns (address);

    function createPair(
        address priceFeedAddress,
        bool _isPriceFeedInverse,
        address tokenAAddress,
        address tokenBAddress
    ) external;

    function getNumPairs() external view returns (uint256);

    function getPair(uint256 id) external view returns (IOrderPool pair);

    function withfrawFees(uint pairId)
        external
        returns (uint256 feesACollected, uint256 feesBCollected);
}
