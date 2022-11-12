// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "../src/OrderPool.sol";
import "../src/OrderPoolFactory.sol";

contract Deploy is Script {
    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(/*deployerPrivateKey*/);

        console.log("Creator: ", msg.sender);

        OrderPoolFactory factory = new OrderPoolFactory();
        console.log("Order Pool Factory deployed: ", address(factory), " owner: ", factory.owner());

        // createPair(ETH/USD chainlink feed, not inverse, WETH, USDC)
        factory.createPair(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, false, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        (IOrderPool p, IOrderPool r) = factory.getPair(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        console.log("Pair deployed:");
        console.log(ERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).symbol(), "/", ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48).symbol());
        console.log("Pool: ", address(p));
        console.log("Reverse Pool: ", address(r));

        vm.stopBroadcast();
    }
}