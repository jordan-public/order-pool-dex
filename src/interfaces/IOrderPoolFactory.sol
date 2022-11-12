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

    function getPair(address tokenAAddress, address tokenBAddress)
        external
        view
        returns (IOrderPool pair, IOrderPool reverse);
}
