// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract OrderPoolTest is Test {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant ORACLE_ETH_USD =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    IOrderPoolFactory factory;
    IOrderPool pool;
    IOrderPool reversePool;

    function setUp() public {
        console.log("Creator: ", msg.sender);

        factory = new OrderPoolFactory();
        console.log(
            "Order Pool Factory deployed: ",
            address(factory),
            " owner: ",
            factory.owner()
        );

        factory.createPair(ORACLE_ETH_USD, false, WETH, USDC);
        (pool, reversePool) = factory.getPair(WETH, USDC);
        console.log("Pair deployed:");
        console.log(ERC20(WETH).symbol(), "/", ERC20(USDC).symbol());
        console.log("Pool: ", address(pool));
        console.log("Reverse Pool: ", address(reversePool));
    }

    function testPriceFeed() public {
        uint256 amount = 10**ERC20(WETH).decimals();
        assertApproxEqRel(
            reversePool.convert(pool.convert(amount)),
            amount,
            10e15
        );
    }
}
