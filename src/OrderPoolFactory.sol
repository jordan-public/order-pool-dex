// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./OrderPool.sol";
import "./interfaces/IOrderPoolFactory.sol";

contract OrderPoolFactory is IOrderPoolFactory {
    address public owner;

    mapping(address => mapping(address => IOrderPool)) public pairs;

    modifier onlyOwner() {
        require(msg.sender == owner, "OrderPoolFactory: Unauthorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getPair(address tokenA, address tokenB)
        public
        view
        returns (IOrderPool pair, IOrderPool reverse)
    {
        (pair, reverse) = (pairs[tokenA][tokenB], pairs[tokenB][tokenA]);
    }

    function createPair(
        address priceFeedAddress,
        bool isPriceFeedInverse,
        address tokenA,
        address tokenB
    ) external onlyOwner {
        require(
            tokenA != address(0) && tokenB != address(0) && tokenA != tokenB,
            "Identical or null tokens."
        );
        // TODO: Check if tokens are ERC20
        require(
            address(0) == address(pairs[tokenA][tokenB]),
            "Pair already exists."
        );
        require(
            address(0) == address(pairs[tokenB][tokenA]),
            "Reverse pair already exists."
        );
        pairs[tokenA][tokenB] = new OrderPool(
            priceFeedAddress,
            isPriceFeedInverse,
            tokenA,
            tokenB
        );
        pairs[tokenB][tokenA] = new OrderPool(
            priceFeedAddress,
            !isPriceFeedInverse,
            tokenB,
            tokenA
        );
        pairs[tokenA][tokenB].setReverse(IOrderPool(pairs[tokenB][tokenA]));
        pairs[tokenB][tokenA].setReverse(IOrderPool(pairs[tokenA][tokenB]));
    }

    function withfrawFees(address tokenA, address tokenB)
        external
        onlyOwner
        returns (uint256 feesACollected, uint256 feesBCollected)
    {
        (IOrderPool p, IOrderPool r) = getPair(tokenA, tokenB);
        feesACollected = p.withdrawFees(msg.sender);
        feesBCollected = r.withdrawFees(msg.sender);
    }
}
