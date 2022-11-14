// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract OrderPoolTest is Test {
    // Mainnet
    // address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    // address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address constant ORACLE_ETH_USD =
    //     0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Görli
    address constant WETH = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address constant USDC = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F;
    address constant ORACLE_ETH_USD =
        0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e;

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
        console.log("WETH / USDC pair created.");
    }

    function testPriceFeed() public {
        uint256 amount = 10**18;
        pool = factory.getPair(factory.getNumPairs() - 1);
        assertApproxEqRel(
            pool.reversePool().convert(pool.convert(amount)),
            amount,
            10e15
        );
    }
}
