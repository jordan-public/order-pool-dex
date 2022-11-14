// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./OrderPool.sol";
import "./interfaces/IOrderPoolFactory.sol";

contract OrderPoolFactory is IOrderPoolFactory {
    address public owner;

    IOrderPool[] pairList;

    modifier onlyOwner() {
        require(msg.sender == owner, "OrderPoolFactory: Unauthorized");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function getNumPairs() external view returns (uint256) {
        return pairList.length;
    }

    function getPair(uint256 id) external view returns (IOrderPool pair) {
        return pairList[id];
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

        IOrderPool p = new OrderPool(
            priceFeedAddress,
            isPriceFeedInverse,
            tokenA,
            tokenB
        );
        IOrderPool r = new OrderPool(
            priceFeedAddress,
            !isPriceFeedInverse,
            tokenB,
            tokenA
        );
        p.setReverse(r);
        r.setReverse(p);
        pairList.push(p); // Duplicates possible - no harm done
    }

    function withfrawFees(uint256 pairId)
        external
        onlyOwner
        returns (uint256 feesACollected, uint256 feesBCollected)
    {
        IOrderPool p = pairList[pairId];
        feesACollected = p.withdrawFees(msg.sender);
        feesBCollected = p.reversePool().withdrawFees(msg.sender);
    }
}
